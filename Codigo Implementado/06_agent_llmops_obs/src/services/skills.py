
from typing import TypedDict

from langchain_core.tools import tool

from src.utils.logger import get_logger

logger = get_logger(__name__)


class Skill(TypedDict):
    """Skill que se revela al agente de forma progresiva."""

    name: str
    description: str
    content: str


SKILLS: list[Skill] = [
    {
        "name": "diagnostico_incidente",
        "description": (
            "Procedimiento para analizar incidentes de infraestructura, "
            "recuperar casos similares y formular hipótesis respaldadas por evidencia."
        ),
        "content": """# Diagnóstico de incidentes de infraestructura

## Objetivo
Analizar un incidente técnico utilizando antecedentes históricos, datos
estructurados y verificaciones de diagnóstico seguras.

## Procedimiento

1. **Comprender el problema**
   - Identifica el componente afectado, el comportamiento observado y el impacto.
   - Considera el mensaje de error, el entorno, la hora de ocurrencia y los cambios recientes, si están disponibles.
   - No inventes datos que el usuario no haya proporcionado.
   - Si falta información importante, puedes solicitarla sin impedir un análisis preliminar.

2. **Buscar antecedentes históricos**
   - Utiliza `search_incident_history` para buscar incidentes similares en Qdrant y consultar sus registros actuales en Neon.
   - Envía una descripción suficientemente completa del incidente actual.
   - La herramienta realiza internamente la búsqueda semántica y la consulta estructurada de los códigos identificados.
   - Examina tanto los candidatos recuperados como los registros obtenidos de Neon.
   - No confundas similitud textual con equivalencia técnica.
   - No supongas que todos los candidatos son pertinentes.
   - No utilices `retrieve_documents` ni `run_sql` para repetir manualmente los pasos que ya realiza esta herramienta.

3. **Interpretar el resultado de la búsqueda**
   - Comprueba el estado devuelto por `search_incident_history`.
   - Si la consulta se completó, utiliza Neon como fuente de verdad para los estados y resultados actuales.
   - Si Qdrant devuelve documentos sin códigos identificables, indica que no fue posible contrastarlos con Neon.
   - Si falla Qdrant o Neon, informa qué parte del análisis no pudo completarse.
   - Si Qdrant no devuelve candidatos, no afirmes que no existen incidentes en toda la base de datos.
   - No afirmes que se consultó correctamente Neon cuando la herramienta indica un error o una consulta incompleta.

4. **Evaluar las posibles causas**
   - Distingue entre hechos registrados e hipótesis confirmadas, descartadas, inconclusas o pendientes.
   - Explica qué evidencia respalda cada posible causa.
   - Si la información es insuficiente, presenta el diagnóstico como preliminar.
   - Si no hay antecedentes pertinentes, solicita información adicional cuando corresponda.

5. **Proponer verificaciones**
   - Prioriza comprobaciones de solo lectura y acciones de diagnóstico de bajo riesgo.
   - Explica qué resultado se espera observar y cómo interpretarlo.
   - No recomiendes cambios destructivos ni irreversibles sin las verificaciones y autorizaciones necesarias.

6. **Comunicar el resultado**
   - Resume el diagnóstico preliminar.
   - Menciona los incidentes históricos relevantes y sus códigos.
   - Distingue las soluciones aplicadas y efectivas de las propuestas pendientes o no efectivas.
   - Indica los siguientes pasos y los datos adicionales que se necesitan.

## Reglas importantes

- No afirmes que no existen antecedentes solo porque no haya una coincidencia exacta.
- No inventes incidentes, hipótesis, soluciones, estados ni resultados.
- No presentes una solución histórica como garantía de éxito en el incidente actual.
- No expongas datos personales ni identificadores internos de las personas involucradas.
""",
    },
    {
        "name": "validacion_solucion",
        "description": (
            "Procedimiento para evaluar soluciones históricas, verificar resultados "
            "y distinguir entre una solución propuesta, aplicada y efectiva."
        ),
        "content": """# Validación de soluciones de infraestructura

## Objetivo
Evaluar la evidencia disponible sobre una solución y orientar la comprobación
de su efectividad sin confundir los resultados históricos con los actuales.

## Procedimiento

1. **Identificar la solución**
   - Para investigar incidentes históricos, utiliza `search_incident_history`.
   - La herramienta busca candidatos en Qdrant y consulta en Neon sus datos actuales, hipótesis, soluciones y adjuntos.
   - Si el usuario proporciona un código de incidente, inclúyelo en la consulta para ayudar a localizar el caso.
   - No invoques `retrieve_documents` y `run_sql` por separado para repetir el flujo que realiza la herramienta combinada.
   - Si la consulta no se completa correctamente, explica la limitación.

2. **Clasificar el estado**
   - **Aplicada y efectiva:** los registros indican que la solución fue aplicada y su resultado registrado es efectivo.
   - **No efectiva:** el resultado registrado indica que no funcionó.
   - **Pendiente de validación:** no existe un resultado concluyente o la solución sigue pendiente.
   - **Estado no determinado:** los registros disponibles no permiten establecer su situación.
   - No deduzcas que una solución es efectiva únicamente porque su estado sea aplicada.

3. **Evaluar la pertinencia**
   - Compara el componente, el síntoma, el mensaje de error y el contexto del incidente histórico con el caso actual.
   - Explica las similitudes y diferencias relevantes.
   - No recomiendes una solución únicamente porque haya funcionado en un incidente distinto.

4. **Definir la comprobación**
   - Describe qué indicador, registro, prueba o comportamiento permitiría verificar la resolución.
   - Prioriza comprobaciones seguras y reversibles.
   - Solicita autorización antes de recomendar cambios que afecten producción.

5. **Comunicar las conclusiones**
   - Separa el resultado histórico del resultado observado en el incidente actual.
   - Si todavía no se ha ejecutado una prueba, no afirmes que el problema está resuelto.
   - Si falta evidencia, especifica qué debe comprobarse y qué información debe recopilarse.

## Reglas importantes

- No inventes resultados de pruebas ni confirmes una resolución sin evidencia.
- No confundas una solución propuesta con una solución aplicada.
- No confundas una solución aplicada con una solución efectiva.
- No interpretes un error de búsqueda como evidencia de que no existen antecedentes.
- No modifiques los registros de las bases de datos salvo que exista una herramienta autorizada y el usuario haya solicitado la acción correspondiente.
- No expongas datos personales ni identificadores internos de las personas involucradas.
""",
    },
]


@tool
def list_skills() -> str:
    """Lista los procedimientos especializados disponibles para el agente."""
    logger.info("Listando %d skill(s)", len(SKILLS))
    return "\n".join(
        f"- {skill['name']}: {skill['description']}"
        for skill in SKILLS
    )


@tool
def load_skill(skill_name: str) -> str:
    """Carga las instrucciones completas de un procedimiento especializado.
    Utilízala con el nombre exacto devuelto por list_skills."""

    for skill in SKILLS:
        if skill["name"] == skill_name:
            logger.info("Skill cargada: %s", skill_name)
            return f"Skill cargada: {skill_name}\n\n{skill['content']}"

    available = ", ".join(skill["name"] for skill in SKILLS)
    logger.warning("Skill no encontrada: %s", skill_name)

    return (
        f"La skill '{skill_name}' no existe. "
        f"Skills disponibles: {available}"
    )


SKILL_TOOLS = [list_skills, load_skill]
