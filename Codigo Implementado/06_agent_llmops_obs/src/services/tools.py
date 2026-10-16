import re
import json

from typing import Any, Dict, List, Tuple

from langchain_core.tools import tool
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_openai import OpenAIEmbeddings
from langchain_qdrant import QdrantVectorStore

from src.services.skills import SKILL_TOOLS
from src.utils.environment import (
    NEON_API_KEY,
    NEON_PROJECT_ID,
    OPENAI_API_KEY,
    QDRANT_KEY,
    QDRANT_COLLECTION_NAME,
    QDRANT_URL,
)
from src.utils.logger import get_logger

logger = get_logger(__name__)


# ============================================================
# 1. HERRAMIENTA EXISTENTE: CLIMA (PLACEHOLDER)
# ============================================================

@tool
def get_weather(location: str) -> str:
    """Devuelve un pronóstico ficticio del clima para una ubicación."""
    return f"El clima en {location} es soleado con una temperatura de 22°C."


# ============================================================
# 2. CONEXIÓN CON QDRANT
# ============================================================

_vector_store: QdrantVectorStore | None = None


def _get_vector_store() -> QdrantVectorStore:
    """Inicializa Qdrant una sola vez y reutiliza la conexión."""
    global _vector_store

    if _vector_store is None:
        logger.info(
            "Inicializando QdrantVectorStore",
            extra={"collection": QDRANT_COLLECTION_NAME},
        )

        embeddings = OpenAIEmbeddings(
            model="text-embedding-3-small",
            api_key=OPENAI_API_KEY,
        )

        _vector_store = QdrantVectorStore.from_existing_collection(
            embedding=embeddings,
            collection_name=QDRANT_COLLECTION_NAME,
            url=QDRANT_URL,
            api_key=QDRANT_KEY,
        )

    return _vector_store


# ============================================================
# 2.1. INTERPRETACIÓN DE LA RESPUESTA DE NEON
# ============================================================

def _parse_neon_incidents(
    raw_response: str,
) -> List[Dict[str, Any]]:
    """
    Interpreta la respuesta de Neon y extrae los incidentes.

    Admite respuestas JSON directas y envoltorios comunes
    utilizados por herramientas MCP. Si el formato no puede
    interpretarse, genera un error explícito.
    """
    if not isinstance(raw_response, str):
        raise ValueError(
            "La respuesta de Neon no es una cadena de texto."
        )

    texto = raw_response.strip()

    if not texto:
        raise ValueError("Neon devolvió una respuesta vacía.")

    try:
        payload = json.loads(texto)
    except json.JSONDecodeError as exc:
        logger.error(
            "La respuesta de Neon no es JSON válido. "
            "Primeros 1000 caracteres: %s",
            texto[:1000],
        )
        raise ValueError(
            "La respuesta de Neon no contiene JSON válido."
        ) from exc

    return _parse_neon_payload_item(payload)


def _parse_neon_payload_item(
    payload: Any,
) -> List[Dict[str, Any]]:
    """Extrae la lista de incidentes de distintos envoltorios JSON."""

    if isinstance(payload, str):
        try:
            payload = json.loads(payload)
        except json.JSONDecodeError as exc:
            raise ValueError(
                "La respuesta de Neon contiene texto no interpretable "
                "como JSON."
            ) from exc

        return _parse_neon_payload_item(payload)

    if isinstance(payload, list):
        if not payload:
            return []

        for item in payload:
            if isinstance(item, dict) and "incidentes" in item:
                return _parse_neon_payload_item(item)

        if all(
            isinstance(item, dict) and "codigo" in item
            for item in payload
        ):
            return payload

        raise ValueError(
            "La lista devuelta por Neon no contiene la columna "
            "'incidentes' ni una lista directa de incidentes."
        )

    if not isinstance(payload, dict):
        raise ValueError(
            "El formato de respuesta de Neon no es compatible."
        )

    if "incidentes" in payload:
        incidentes = payload["incidentes"]

        if isinstance(incidentes, str):
            try:
                incidentes = json.loads(incidentes)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    "La columna incidentes no contiene JSON válido."
                ) from exc

        if not isinstance(incidentes, list):
            raise ValueError(
                "La columna incidentes no es una lista JSON."
            )

        if not all(isinstance(item, dict) for item in incidentes):
            raise ValueError(
                "La lista de incidentes contiene elementos inesperados."
            )

        return incidentes

    for key in ("result", "rows", "data"):
        if key in payload:
            return _parse_neon_payload_item(payload[key])

    raise ValueError(
        "No se encontró la columna 'incidentes' "
        "en la respuesta de Neon."
    )


# ============================================================
# 2.2. BÚSQUEDA HISTÓRICA: QDRANT + NEON
# ============================================================

@tool(response_format="content_and_artifact")
async def search_incident_history(
    query: str,
    k: int = 4,
) -> Tuple[str, List[Dict[str, Any]]]:
    """
    Busca incidentes históricos.

    Si la consulta contiene un código INC- explícito, verifica
    primero su existencia exacta en Neon, sin depender de Qdrant.

    Si no contiene un código explícito, utiliza Qdrant para
    recuperar incidentes similares y contrasta sus datos con Neon.
    """

    # --------------------------------------------------------
    # PASO 1. DETECTAR SI EL USUARIO INDICA UN CÓDIGO EXPLÍCITO
    # --------------------------------------------------------

    codigos_explicitos = sorted({
        codigo.upper()
        for codigo in re.findall(
            r"(?<![A-Z0-9])INC-\d+(?!\d)",
            query,
            flags=re.IGNORECASE,
        )
    })

    # --------------------------------------------------------
    # PASO 2. SI HAY CÓDIGO EXPLÍCITO, CONSULTAR NEON PRIMERO
    # --------------------------------------------------------

    if codigos_explicitos:
        # Los códigos se extraen mediante una expresión regular
        # estricta y solo contienen INC- seguido de dígitos.
        # Aun así, se escapan las comillas antes de construir SQL.
        lista_codigos_sql = ", ".join(
            "'" + codigo.replace("'", "''") + "'"
            for codigo in codigos_explicitos
        )

        sql = f"""
            SELECT COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', i.id,
                        'codigo', i.codigo,
                        'titulo', i.titulo,
                        'descripcion', i.descripcion,
                        'componente', i.componente,
                        'mensaje_error', i.mensaje_error,
                        'estado', i.estado,
                        'fecha_creacion', i.fecha_creacion,

                        'hipotesis', COALESCE((
                            SELECT jsonb_agg(
                                jsonb_build_object(
                                    'descripcion', h.descripcion,
                                    'evidencia', h.evidencia,
                                    'estado', h.estado,
                                    'fecha_creacion', h.fecha_creacion
                                )
                            )
                            FROM public.hipotesis h
                            WHERE h.id_incidente = i.id
                        ), '[]'::jsonb),

                        'soluciones', COALESCE((
                            SELECT jsonb_agg(
                                jsonb_build_object(
                                    'descripcion', s.descripcion,
                                    'estado', s.estado,
                                    'resultado', s.resultado,
                                    'fecha_creacion', s.fecha_creacion
                                )
                            )
                            FROM public.soluciones s
                            WHERE s.id_incidente = i.id
                        ), '[]'::jsonb),

                        'adjuntos', COALESCE((
                            SELECT jsonb_agg(
                                jsonb_build_object(
                                    'nombre_archivo', a.nombre_archivo,
                                    'texto_extraido', a.texto_extraido,
                                    'fecha_creacion', a.fecha_creacion
                                )
                            )
                            FROM public.adjuntos_incidente a
                            WHERE a.id_incidente = i.id
                        ), '[]'::jsonb)
                    )
                    ORDER BY i.codigo
                ),
                '[]'::jsonb
            ) AS incidentes
            FROM public.incidentes i
            WHERE UPPER(i.codigo) IN ({lista_codigos_sql});
        """

        logger.info(
            "Verificación exacta en Neon para códigos: %s",
            codigos_explicitos,
        )

        try:
            resultado_raw = await _run_analytics_sql(sql)
            incidentes = _parse_neon_incidents(resultado_raw)

        except Exception as exc:
            logger.exception(
                "Falló la verificación exacta de códigos en Neon."
            )

            return (
                json.dumps(
                    {
                        "estado": "error_neon",
                        "mensaje": (
                            "No fue posible verificar en Neon la "
                            "existencia de los códigos solicitados. "
                            "No se puede concluir que no existan."
                        ),
                        "codigos_solicitados": codigos_explicitos,
                        "detalle_tecnico": str(exc),
                        "incidentes_neon": None,
                    },
                    ensure_ascii=False,
                    default=str,
                ),
                [],
            )

        codigos_encontrados = {
            str(item.get("codigo", "")).upper()
            for item in incidentes
            if item.get("codigo")
        }

        codigos_no_encontrados = [
            codigo
            for codigo in codigos_explicitos
            if codigo not in codigos_encontrados
        ]

        # No ejecutamos la búsqueda semántica para sustituir
        # un código que no existe por incidentes parecidos.
        if codigos_no_encontrados:
            estado = (
                "incidente_no_encontrado"
                if not incidentes
                else "verificacion_parcial"
            )

            mensaje = (
                "No se encontraron en Neon los siguientes códigos: "
                + ", ".join(codigos_no_encontrados)
                + ". No deben atribuirse a esos códigos datos ni "
                  "soluciones de otros incidentes."
            )

            respuesta = {
                "estado": estado,
                "mensaje": mensaje,
                "codigos_solicitados": codigos_explicitos,
                "codigos_encontrados": sorted(codigos_encontrados),
                "codigos_no_encontrados": codigos_no_encontrados,
                "incidentes_neon": incidentes,
                "instruccion": (
                    "Informa qué códigos no existen en los resultados "
                    "de la consulta. No inventes registros ni atribuyas "
                    "a los códigos ausentes soluciones de otros casos. "
                    "Los incidentes encontrados corresponden únicamente "
                    "a sus propios códigos."
                ),
            }

            return (
                json.dumps(
                    respuesta,
                    ensure_ascii=False,
                    default=str,
                ),
                incidentes,
            )

        # Todos los códigos explícitos fueron verificados.
        respuesta = {
            "estado": "incidente_encontrado",
            "mensaje": (
                "Los códigos solicitados se verificaron mediante "
                "una consulta exacta en Neon."
            ),
            "codigos_solicitados": codigos_explicitos,
            "codigos_encontrados": sorted(codigos_encontrados),
            "incidentes_neon": incidentes,
            "instruccion": (
                "Responde usando los registros actuales de Neon. "
                "Distingue hechos, hipótesis y soluciones según sus "
                "estados y resultados registrados. No inventes datos."
            ),
        }

        return (
            json.dumps(
                respuesta,
                ensure_ascii=False,
                default=str,
            ),
            incidentes,
        )

    # --------------------------------------------------------
    # PASO 3. SI NO HAY CÓDIGO EXPLÍCITO, BUSCAR EN QDRANT
    # --------------------------------------------------------

    try:
        vector_store = _get_vector_store()

        results = vector_store.similarity_search_with_score(
            query,
            k=max(1, min(k, 8)),
        )

    except Exception as exc:
        logger.exception("Falló la búsqueda semántica en Qdrant.")

        return (
            json.dumps(
                {
                    "estado": "error_qdrant",
                    "mensaje": (
                        "No fue posible consultar Qdrant. "
                        "No se puede concluir que no existan incidentes."
                    ),
                    "detalle_tecnico": str(exc),
                    "incidentes_neon": None,
                },
                ensure_ascii=False,
                default=str,
            ),
            [],
        )

    if not results:
        return (
            json.dumps(
                {
                    "estado": "sin_resultados_qdrant",
                    "mensaje": (
                        "Qdrant no devolvió incidentes similares. "
                        "Esto no demuestra que Neon carezca de registros."
                    ),
                    "candidatos_qdrant": [],
                    "incidentes_neon": None,
                },
                ensure_ascii=False,
            ),
            [],
        )

    # --------------------------------------------------------
    # PASO 4. RECUPERAR PAYLOADS Y EXTRAER CÓDIGOS
    # --------------------------------------------------------

    point_ids = list({
        str(doc.metadata["_id"])
        for doc, _ in results
        if doc.metadata and doc.metadata.get("_id")
    })

    payloads_por_id: Dict[str, Dict[str, Any]] = {}

    if point_ids:
        try:
            points = vector_store.client.retrieve(
                collection_name=QDRANT_COLLECTION_NAME,
                ids=point_ids,
                with_payload=True,
                with_vectors=False,
            )

            for point in points:
                payloads_por_id[str(point.id)] = point.payload or {}

        except Exception:
            logger.exception(
                "No se pudo recuperar el payload original de Qdrant."
            )

    candidatos: List[Dict[str, Any]] = []
    codigos = set()

    for doc, score in results:
        metadata = doc.metadata or {}
        qdrant_id = str(metadata.get("_id", ""))
        payload = payloads_por_id.get(qdrant_id, {})

        contenido_payload = payload.get("page_content", "")
        metadata_payload = payload.get("metadata", {})

        textos = "\n".join([
            doc.page_content or "",
            json.dumps(metadata, ensure_ascii=False, default=str),
            str(contenido_payload or ""),
            json.dumps(metadata_payload, ensure_ascii=False, default=str),
            json.dumps(payload, ensure_ascii=False, default=str),
        ])

        codigos_documento = {
            codigo.upper()
            for codigo in re.findall(
                r"\bINC-\d+\b",
                textos,
                flags=re.IGNORECASE,
            )
        }

        codigos.update(codigos_documento)

        candidatos.append({
            "codigos": sorted(codigos_documento),
            "qdrant_id": qdrant_id,
            "contenido": doc.page_content or str(contenido_payload or ""),
            "metadata": metadata,
            "score": float(score),
        })

    if not codigos:
        return (
            json.dumps(
                {
                    "estado": "codigos_no_identificados",
                    "mensaje": (
                        "Qdrant devolvió documentos, pero no fue posible "
                        "identificar códigos de incidentes para contrastar "
                        "los resultados con Neon."
                    ),
                    "candidatos_qdrant": candidatos,
                    "incidentes_neon": None,
                },
                ensure_ascii=False,
                default=str,
            ),
            candidatos,
        )

    # --------------------------------------------------------
    # PASO 5. CONSULTAR EN NEON LOS CÓDIGOS RECUPERADOS
    # --------------------------------------------------------

    lista_codigos_sql = ", ".join(
        "'" + codigo.replace("'", "''") + "'"
        for codigo in sorted(codigos)
    )

    sql = f"""
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', i.id,
                    'codigo', i.codigo,
                    'titulo', i.titulo,
                    'descripcion', i.descripcion,
                    'componente', i.componente,
                    'mensaje_error', i.mensaje_error,
                    'estado', i.estado,
                    'fecha_creacion', i.fecha_creacion,

                    'hipotesis', COALESCE((
                        SELECT jsonb_agg(jsonb_build_object(
                            'descripcion', h.descripcion,
                            'evidencia', h.evidencia,
                            'estado', h.estado,
                            'fecha_creacion', h.fecha_creacion
                        ))
                        FROM public.hipotesis h
                        WHERE h.id_incidente = i.id
                    ), '[]'::jsonb),

                    'soluciones', COALESCE((
                        SELECT jsonb_agg(jsonb_build_object(
                            'descripcion', s.descripcion,
                            'estado', s.estado,
                            'resultado', s.resultado,
                            'fecha_creacion', s.fecha_creacion
                        ))
                        FROM public.soluciones s
                        WHERE s.id_incidente = i.id
                    ), '[]'::jsonb),

                    'adjuntos', COALESCE((
                        SELECT jsonb_agg(jsonb_build_object(
                            'nombre_archivo', a.nombre_archivo,
                            'texto_extraido', a.texto_extraido,
                            'fecha_creacion', a.fecha_creacion
                        ))
                        FROM public.adjuntos_incidente a
                        WHERE a.id_incidente = i.id
                    ), '[]'::jsonb)
                )
                ORDER BY i.codigo
            ),
            '[]'::jsonb
        ) AS incidentes
        FROM public.incidentes i
        WHERE UPPER(i.codigo) IN ({lista_codigos_sql});
    """

    try:
        resultado_raw = await _run_analytics_sql(sql)
        incidentes = _parse_neon_incidents(resultado_raw)

    except Exception as exc:
        logger.exception(
            "Falló la consulta de antecedentes semánticos en Neon."
        )

        return (
            json.dumps(
                {
                    "estado": "error_neon",
                    "mensaje": (
                        "Qdrant recuperó candidatos, pero no fue posible "
                        "verificar sus datos actuales en Neon."
                    ),
                    "detalle_tecnico": str(exc),
                    "codigos_busqueda": sorted(codigos),
                    "candidatos_qdrant": candidatos,
                    "incidentes_neon": None,
                },
                ensure_ascii=False,
                default=str,
            ),
            candidatos,
        )

    codigos_neon = {
        str(item.get("codigo", "")).upper()
        for item in incidentes
        if item.get("codigo")
    }

    respuesta = {
        "estado": (
            "consulta_completada"
            if incidentes
            else "sin_coincidencias_neon"
        ),
        "mensaje": (
            "Se recuperaron antecedentes y se contrastaron con Neon."
            if incidentes
            else (
                "Los códigos recuperados de Qdrant no coincidieron "
                "con registros de Neon."
            )
        ),
        "codigos_busqueda": sorted(codigos),
        "codigos_neon": sorted(codigos_neon),
        "candidatos_qdrant": candidatos,
        "incidentes_neon": incidentes,
        "instruccion": (
            "Usa Neon como fuente de verdad. Presenta los casos como "
            "antecedentes similares, no como equivalentes al problema "
            "actual. Distingue los estados y resultados registrados."
        ),
    }

    return (
        json.dumps(
            respuesta,
            ensure_ascii=False,
            default=str,
        ),
        candidatos,
    )





# ============================================================
# 3. HERRAMIENTA LEGADA: RECUPERACIÓN DE DOCUMENTOS
# ============================================================

@tool(response_format="content_and_artifact")
def retrieve_documents(
    query: str,
    k: int = 4,
) -> Tuple[str, List[Dict[str, Any]]]:
    """Busca documentos semánticamente similares en Qdrant."""

    vector_store = _get_vector_store()

    results = vector_store.similarity_search_with_score(
        query,
        k=k,
    )

    if not results:
        return "No se encontraron documentos relevantes.", []

    contexts: List[Dict[str, Any]] = []
    content_parts: List[str] = []

    for doc, score in results:
        contexts.append(
            {
                "page_content": doc.page_content,
                "metadata": doc.metadata,
                "score": float(score),
            }
        )

        content_parts.append(doc.page_content)

    content = "\n\n---\n\n".join(content_parts)

    return content, contexts


# ============================================================
# 4. CONEXIÓN CON LAS HERRAMIENTAS MCP DE NEON
# ============================================================

_neon_run_sql_tool = None


async def _run_analytics_sql(sql: str) -> str:
    """Ejecuta una consulta SQL mediante la herramienta MCP de Neon."""

    if _neon_run_sql_tool is None:
        raise RuntimeError(
            "La herramienta run_sql de Neon no está inicializada. "
            "Verifica que load_neon_tools() se haya ejecutado "
            "correctamente antes de utilizar las herramientas analíticas."
        )

    resultado = await _neon_run_sql_tool.ainvoke(
        {
            "project_id": NEON_PROJECT_ID,
            "sql": sql,
        }
    )

    logger.debug(
        "Respuesta MCP original: tipo=%s; contenido=%s",
        type(resultado).__name__,
        str(resultado)[:3000],
    )

    if isinstance(resultado, list):
        partes = [
            item["text"]
            for item in resultado
            if isinstance(item, dict) and "text" in item
        ]

        if partes:
            return "\n".join(partes)

    if isinstance(resultado, str):
        return resultado

    if isinstance(resultado, dict):
        return json.dumps(
            resultado,
            ensure_ascii=False,
            default=str,
        )

    return str(resultado)


# ============================================================
# 5. TOOL ANALÍTICA: RESUMEN DE INCIDENTES
# ============================================================

@tool
async def get_incident_summary() -> str:
    """Obtiene el total de incidentes y su distribución
    por componente y estado."""

    sql = """
        SELECT jsonb_pretty(
            jsonb_build_object(
                'total_incidentes',
                (SELECT COUNT(*) FROM public.incidentes),

                'incidentes_por_componente_y_estado',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                            to_jsonb(r)
                            ORDER BY r.componente, r.estado
                        )
                        FROM (
                            SELECT
                                componente,
                                estado,
                                COUNT(*) AS cantidad
                            FROM public.incidentes
                            GROUP BY componente, estado
                        ) r
                    ),
                    '[]'::jsonb
                )
            )
        ) AS reporte;
    """

    return await _run_analytics_sql(sql)


# ============================================================
# 6. TOOL ANALÍTICA: TENDENCIA MENSUAL
# ============================================================

@tool
async def get_monthly_incident_trend() -> str:
    """Obtiene la cantidad de incidentes registrados por mes."""

    sql = """
        SELECT jsonb_pretty(
            COALESCE(
                jsonb_agg(
                    to_jsonb(r)
                    ORDER BY r.mes
                ),
                '[]'::jsonb
            )
        ) AS reporte
        FROM (
            SELECT
                DATE_TRUNC(
                    'month',
                    fecha_creacion
                )::date AS mes,
                COUNT(*) AS total
            FROM public.incidentes
            GROUP BY DATE_TRUNC('month', fecha_creacion)
        ) r;
    """

    return await _run_analytics_sql(sql)


# ============================================================
# 7. TOOL ANALÍTICA: EFECTIVIDAD DE SOLUCIONES
# ============================================================

@tool
async def get_solution_effectiveness() -> str:
    """Obtiene las soluciones efectivas, pendientes y no efectivas."""

    sql = """
        SELECT jsonb_pretty(
            COALESCE(
                jsonb_agg(
                    to_jsonb(r)
                    ORDER BY r.componente
                ),
                '[]'::jsonb
            )
        ) AS reporte
        FROM (
            SELECT
                i.componente,
                COUNT(s.id) AS total_soluciones,

                COUNT(s.id) FILTER (
                    WHERE LOWER(s.resultado) = 'efectiva'
                ) AS efectivas,

                COUNT(s.id) FILTER (
                    WHERE LOWER(s.resultado) = 'pendiente'
                ) AS pendientes,

                COUNT(s.id) FILTER (
                    WHERE LOWER(s.resultado) = 'no_efectiva'
                ) AS no_efectivas

            FROM public.incidentes i
            LEFT JOIN public.soluciones s
                ON s.id_incidente = i.id
            GROUP BY i.componente
        ) r;
    """

    return await _run_analytics_sql(sql)


# ============================================================
# 8. TOOL ANALÍTICA: RESUMEN DE HIPÓTESIS
# ============================================================

@tool
async def get_hypothesis_summary() -> str:
    """Obtiene la cantidad de hipótesis agrupadas por estado."""

    sql = """
        SELECT jsonb_pretty(
            COALESCE(
                jsonb_agg(
                    to_jsonb(r)
                    ORDER BY r.estado
                ),
                '[]'::jsonb
            )
        ) AS reporte
        FROM (
            SELECT
                estado,
                COUNT(*) AS cantidad
            FROM public.hipotesis
            GROUP BY estado
        ) r;
    """

    return await _run_analytics_sql(sql)


# ============================================================
# 9. TOOL ANALÍTICA: USO DEL AGENTE Y FEEDBACK
# ============================================================

@tool
async def get_agent_usage_metrics() -> str:
    """Obtiene métricas de uso, feedback y contexto recuperado."""

    sql = """
        WITH resumen_historial AS (
            SELECT
                COUNT(*) AS interacciones,

                COUNT(*) FILTER (
                    WHERE is_ok = TRUE
                ) AS positivas,

                COUNT(*) FILTER (
                    WHERE is_ok = FALSE
                ) AS negativas,

                COUNT(*) FILTER (
                    WHERE retrieved_contexts IS NOT NULL
                    AND retrieved_contexts <> ''
                ) AS con_contexto_recuperado

            FROM public.history
        ),

        incidentes_consultados AS (
            SELECT
                ctx.codigo,
                COUNT(*) AS veces_recuperado

            FROM public.history h

            CROSS JOIN LATERAL
                JSONB_ARRAY_ELEMENTS_TEXT(
                    CASE
                        WHEN h.retrieved_contexts IS NOT NULL
                        AND h.retrieved_contexts <> ''
                        AND JSONB_TYPEOF(
                            h.retrieved_contexts::jsonb
                        ) = 'array'
                        THEN h.retrieved_contexts::jsonb

                        ELSE '[]'::jsonb
                    END
                ) AS ctx(codigo)

            GROUP BY ctx.codigo

            ORDER BY
                veces_recuperado DESC,
                ctx.codigo

            LIMIT 10
        )

        SELECT jsonb_pretty(
            jsonb_build_object(
                'historial',
                (
                    SELECT to_jsonb(h)
                    FROM resumen_historial h
                ),

                'incidentes_mas_recuperados',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                            to_jsonb(ic)
                            ORDER BY
                                ic.veces_recuperado DESC,
                                ic.codigo
                        )
                        FROM incidentes_consultados ic
                    ),
                    '[]'::jsonb
                )
            )
        ) AS reporte;
    """

    return await _run_analytics_sql(sql)


# ============================================================
# 10. REGISTRO DE LAS TOOLS ANALÍTICAS
# ============================================================

ANALYTICS_TOOLS = [
    get_incident_summary,
    get_monthly_incident_trend,
    get_solution_effectiveness,
    get_hypothesis_summary,
    get_agent_usage_metrics,
]


# ============================================================
# 11. CARGA DE HERRAMIENTAS MCP DE NEON
# ============================================================

async def load_neon_tools() -> Tuple[list, object | None]:
    """Conecta al MCP de Neon y prepara run_sql."""

    global _neon_run_sql_tool

    if not NEON_API_KEY:
        logger.warning(
            "NEON_API_KEY no configurado. "
            "Se omite la integración con Neon MCP."
        )
        _neon_run_sql_tool = None
        return [], None

    client = MultiServerMCPClient(
        {
            "neon": {
                "transport": "streamable_http",
                "url": "https://mcp.neon.tech/mcp",
                "headers": {
                    "Authorization": f"Bearer {NEON_API_KEY}"
                },
            }
        }
    )

    tools = await client.get_tools()

    _neon_run_sql_tool = next(
        (t for t in tools if t.name == "run_sql"),
        None,
    )

    if _neon_run_sql_tool is None:
        logger.error(
            "Neon MCP no proporcionó la herramienta run_sql."
        )
    else:
        logger.info(
            "Herramienta run_sql inicializada para el proyecto %s.",
            NEON_PROJECT_ID,
        )

    logger.info(
        "Herramientas MCP de Neon cargadas: %d",
        len(tools),
    )

    return tools, client


# ============================================================
# 12. REGISTRO DE LAS HERRAMIENTAS DEL AGENTE
# ============================================================

LOCAL_TOOLS = [
    get_weather,
    search_incident_history,
    *ANALYTICS_TOOLS,
    *SKILL_TOOLS,
]


def get_all_tools(mcp_tools: list | None = None) -> list:
    """
    Registra únicamente las herramientas locales permitidas.
    Las herramientas MCP de Neon se utilizan internamente y
    no se exponen directamente al LLM.
    """

    all_tools = list(LOCAL_TOOLS)

    logger.info(
        "Herramientas locales registradas: %d; nombres=%s",
        len(all_tools),
        [t.name for t in all_tools],
    )

    if mcp_tools:
        logger.info(
            "Se recibieron %d herramientas MCP de Neon; "
            "no se exponen directamente al agente.",
            len(mcp_tools),
        )

    return all_tools
