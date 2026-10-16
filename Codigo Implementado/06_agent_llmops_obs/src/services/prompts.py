import logging
from pathlib import Path

from src.utils.environment import NEON_PROJECT_ID, PROMPT_VERSION

# Configuración del logger
logger = logging.getLogger(__name__)

# Prompts versionados: el texto del system prompt vive en
# prompts/system/{PROMPT_VERSION}.md.
PROMPTS_DIR = Path(__file__).resolve().parents[2] / "prompts" / "system"

_neon_context = (
    f"Tienes acceso a una base de datos Neon PostgreSQL. "
    f"El project_id que debes usar SIEMPRE en las herramientas MCP "
    f"es: {NEON_PROJECT_ID}. "
    f"Nunca le preguntes al usuario el project_id. "

    f"La base de datos contiene las siguientes tablas: "
    f"- incidentes: "
    f"(id, codigo, titulo, descripcion, componente, mensaje_error, "
    f"estado, reportado_por_id, fecha_creacion). "

    f"- hipotesis: "
    f"(id, id_incidente, descripcion, evidencia, estado, "
    f"propuesto_por_id, evaluado_por_id, fecha_creacion). "

    f"- soluciones: "
    f"(id, id_incidente, id_hipotesis, descripcion, estado, "
    f"resultado, propuesto_por_id, aplicado_por_id, "
    f"validado_por_id, fecha_creacion). "

    f"- adjuntos_incidente: "
    f"(id, id_incidente, nombre_archivo, ubicacion_archivo, "
    f"texto_extraido, cargado_por_id, fecha_creacion). "

    f"Cuando el usuario describa un incidente técnico, "
    f"utiliza primero la herramienta de búsqueda semántica "
    f"de Qdrant disponible en el agente para recuperar "
    f"incidentes similares. "

    f"Después, utiliza run_sql con el project_id indicado "
    f"para consultar en Neon los datos actuales de los "
    f"incidentes recuperados, incluyendo sus hipótesis, "
    f"soluciones y adjuntos pertinentes. "

    f"Relaciona las tablas mediante sus claves foráneas. "
    f"En soluciones, id_hipotesis puede ser nulo. "

    f"Prioriza las soluciones cuyo estado sea 'aplicada' "
    f"y cuyo resultado sea 'efectiva', siempre que sean "
    f"pertinentes para el incidente consultado. "

    f"Distingue las soluciones efectivas de las propuestas "
    f"pendientes y de las soluciones no efectivas. "
    f"No presentes hipótesis pendientes como hechos "
    f"confirmados ni soluciones propuestas como comprobadas. "

    f"Neon es la fuente de verdad para los estados y "
    f"resultados actuales. Si no hay información suficiente, "
    f"indícalo y no inventes datos. "

    f"No expongas identificadores internos de personas "
    f"ni datos personales en las respuestas al usuario. "
) if NEON_PROJECT_ID else ""


def load_system_prompt(version: str = PROMPT_VERSION) -> str:
    """Carga el system prompt e imprime el archivo MD utilizado."""

    path = PROMPTS_DIR / f"{version}.md"

    # Diagnóstico temporal: mostrar directamente en la consola
    print("=" * 60, flush=True)
    print(f"PROMPT_VERSION = {PROMPT_VERSION}", flush=True)
    print(f"Versión solicitada = {version}", flush=True)
    print(f"Archivo MD = {path.name}", flush=True)
    print(f"Ruta completa = {path.resolve()}", flush=True)
    print(f"¿Existe el archivo? = {path.is_file()}", flush=True)
    print("=" * 60, flush=True)

    if not path.is_file():
        raise FileNotFoundError(
            f"No existe el prompt versionado: {path.resolve()}"
        )

    template = path.read_text(encoding="utf-8").strip()

    print(f"Prompt cargado correctamente: {path.name}", flush=True)

    return template.replace("{neon_context}", _neon_context).strip()


SYSTEM_PROMPT = load_system_prompt()
