
-- ============================================================
-- PROYECTO: Agente de IA para asistencia técnica
-- BASE DE DATOS: Neon / PostgreSQL
--
-- FINALIDAD:
-- Registrar incidentes, hipótesis, soluciones y archivos
-- relacionados para utilizarlos como conocimiento de un agente
-- de inteligencia artificial.
--
-- IMPORTANTE:
-- Este script elimina y vuelve a crear las cuatro tablas
-- principales. TODOS SUS DATOS EXISTENTES SE PIERDEN.
--
-- La tabla history NO se elimina.
--
-- Los identificadores de colaboradores tienen el formato
-- A seguido de cinco dígitos: A00001, A00002, etc.
-- Los identificadores internos de las entidades siguen siendo UUID.
-- ============================================================

BEGIN;


-- ============================================================
-- 1. ELIMINAR Y RECREAR LAS CUATRO TABLAS PRINCIPALES
-- ============================================================

DROP TABLE IF EXISTS adjuntos_incidente CASCADE;
DROP TABLE IF EXISTS soluciones CASCADE;
DROP TABLE IF EXISTS hipotesis CASCADE;
DROP TABLE IF EXISTS incidentes CASCADE;
DROP TABLE IF EXISTS history CASCADE;


-- ============================================================
-- 2. TABLA: incidentes
-- ============================================================

CREATE TABLE incidentes (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    codigo VARCHAR(30) NOT NULL UNIQUE,

    titulo VARCHAR(200) NOT NULL,

    descripcion TEXT NOT NULL,

    componente VARCHAR(150),

    mensaje_error TEXT,

    estado VARCHAR(20) NOT NULL DEFAULT 'abierto'
        CHECK (
            estado IN ('abierto', 'investigando', 'resuelto')
        ),

    reportado_por_id VARCHAR(6)
        CHECK (reportado_por_id ~ '^A[0-9]{5}$'),

    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE incidentes IS
'Registra los problemas técnicos que sirven como base de conocimiento para el agente de IA.';

COMMENT ON COLUMN incidentes.id IS
'Identificador UUID único del incidente en la base de datos.';

COMMENT ON COLUMN incidentes.codigo IS
'Código legible y único del incidente, por ejemplo INC-001.';

COMMENT ON COLUMN incidentes.titulo IS
'Resumen breve del problema técnico.';

COMMENT ON COLUMN incidentes.descripcion IS
'Descripción del problema, síntomas y contexto conocido.';

COMMENT ON COLUMN incidentes.componente IS
'Sistema, servicio o componente tecnológico afectado.';

COMMENT ON COLUMN incidentes.mensaje_error IS
'Mensaje de error literal útil para buscar incidentes similares.';

COMMENT ON COLUMN incidentes.estado IS
'Estado actual del incidente: abierto, investigando o resuelto.';

COMMENT ON COLUMN incidentes.reportado_por_id IS
'Identificador seudonimizado del colaborador que reportó el incidente, con formato A seguido de cinco dígitos.';

COMMENT ON COLUMN incidentes.fecha_creacion IS
'Fecha y hora de registro del incidente.';


-- ============================================================
-- 3. TABLA: hipotesis
-- ============================================================

CREATE TABLE hipotesis (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    id_incidente UUID NOT NULL
        REFERENCES incidentes(id) ON DELETE CASCADE,

    descripcion TEXT NOT NULL,

    evidencia TEXT,

    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
        CHECK (
            estado IN (
                'pendiente',
                'confirmada',
                'descartada',
                'inconclusa'
            )
        ),

    propuesto_por_id VARCHAR(6)
        CHECK (propuesto_por_id ~ '^A[0-9]{5}$'),

    evaluado_por_id VARCHAR(6)
        CHECK (evaluado_por_id ~ '^A[0-9]{5}$'),

    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE hipotesis IS
'Registra posibles causas de los incidentes y el estado de su evaluación.';

COMMENT ON COLUMN hipotesis.id IS
'Identificador UUID único de la hipótesis.';

COMMENT ON COLUMN hipotesis.id_incidente IS
'Identificador del incidente al que pertenece esta hipótesis.';

COMMENT ON COLUMN hipotesis.descripcion IS
'Posible causa que explicaría el comportamiento observado.';

COMMENT ON COLUMN hipotesis.evidencia IS
'Logs, pruebas u observaciones que apoyan o contradicen la hipótesis.';

COMMENT ON COLUMN hipotesis.estado IS
'Estado de la hipótesis: pendiente, confirmada, descartada o inconclusa.';

COMMENT ON COLUMN hipotesis.propuesto_por_id IS
'Identificador seudonimizado del colaborador que propuso la hipótesis, con formato A seguido de cinco dígitos.';

COMMENT ON COLUMN hipotesis.evaluado_por_id IS
'Identificador seudonimizado del colaborador que evaluó la hipótesis, con formato A seguido de cinco dígitos.';

COMMENT ON COLUMN hipotesis.fecha_creacion IS
'Fecha y hora de registro de la hipótesis.';


-- ============================================================
-- 4. TABLA: soluciones
-- ============================================================

CREATE TABLE soluciones (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    id_incidente UUID NOT NULL
        REFERENCES incidentes(id) ON DELETE CASCADE,

    id_hipotesis UUID
        REFERENCES hipotesis(id) ON DELETE SET NULL,

    descripcion TEXT NOT NULL,

    estado VARCHAR(20) NOT NULL DEFAULT 'propuesta'
        CHECK (
            estado IN ('propuesta', 'aplicada', 'retirada')
        ),

    resultado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
        CHECK (
            resultado IN (
                'pendiente',
                'efectiva',
                'no_efectiva'
            )
        ),

    propuesto_por_id VARCHAR(6)
        CHECK (propuesto_por_id ~ '^A[0-9]{5}$'),

    aplicado_por_id VARCHAR(6)
        CHECK (aplicado_por_id ~ '^A[0-9]{5}$'),

    validado_por_id VARCHAR(6)
        CHECK (validado_por_id ~ '^A[0-9]{5}$'),

    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE soluciones IS
'Registra acciones técnicas propuestas o aplicadas para resolver o mitigar incidentes.';

COMMENT ON COLUMN soluciones.id IS
'Identificador UUID único de la solución.';

COMMENT ON COLUMN soluciones.id_incidente IS
'Identificador del incidente al que se asocia la solución.';

COMMENT ON COLUMN soluciones.id_hipotesis IS
'Identificador de la hipótesis relacionada, si corresponde.';

COMMENT ON COLUMN soluciones.descripcion IS
'Descripción de la acción técnica y de los pasos de aplicación conocidos.';

COMMENT ON COLUMN soluciones.estado IS
'Estado de ejecución: propuesta, aplicada o retirada.';

COMMENT ON COLUMN soluciones.resultado IS
'Resultado observado: pendiente, efectiva o no_efectiva. Debe basarse en evidencia.';

COMMENT ON COLUMN soluciones.propuesto_por_id IS
'Identificador seudonimizado del colaborador que propuso la solución, con formato A seguido de cinco dígitos.';

COMMENT ON COLUMN soluciones.aplicado_por_id IS
'Identificador seudonimizado del colaborador que aplicó la solución, con formato A seguido de cinco dígitos.';

COMMENT ON COLUMN soluciones.validado_por_id IS
'Identificador seudonimizado del colaborador que validó el resultado de la solución, con formato A seguido de cinco dígitos.';

COMMENT ON COLUMN soluciones.fecha_creacion IS
'Fecha y hora de registro de la solución.';


-- ============================================================
-- 5. TABLA: adjuntos_incidente
-- ============================================================

CREATE TABLE adjuntos_incidente (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    id_incidente UUID NOT NULL
        REFERENCES incidentes(id) ON DELETE CASCADE,

    nombre_archivo VARCHAR(255) NOT NULL,

    ubicacion_archivo TEXT NOT NULL,

    texto_extraido TEXT,

    cargado_por_id VARCHAR(6)
        CHECK (cargado_por_id ~ '^A[0-9]{5}$'),

    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE adjuntos_incidente IS
'Guarda referencias a archivos externos relacionados con incidentes técnicos.';

COMMENT ON COLUMN adjuntos_incidente.id IS
'Identificador UUID único del registro del adjunto.';

COMMENT ON COLUMN adjuntos_incidente.id_incidente IS
'Identificador del incidente al que pertenece el archivo.';

COMMENT ON COLUMN adjuntos_incidente.nombre_archivo IS
'Nombre original del archivo adjunto.';

COMMENT ON COLUMN adjuntos_incidente.ubicacion_archivo IS
'Ruta o URL para localizar el archivo almacenado fuera de PostgreSQL.';

COMMENT ON COLUMN adjuntos_incidente.texto_extraido IS
'Texto obtenido mediante lectura de logs, extracción documental u OCR de imágenes.';

COMMENT ON COLUMN adjuntos_incidente.cargado_por_id IS
'Identificador seudonimizado del colaborador que registró o cargó el adjunto, con formato A seguido de cinco dígitos.';

COMMENT ON COLUMN adjuntos_incidente.fecha_creacion IS
'Fecha y hora de registro de la referencia al archivo.';


-- ============================================================
-- 6. ÍNDICES DE LAS CUATRO TABLAS PRINCIPALES
-- ============================================================

CREATE INDEX idx_incidentes_estado
    ON incidentes(estado);

CREATE INDEX idx_incidentes_componente
    ON incidentes(componente);

CREATE INDEX idx_hipotesis_incidente
    ON hipotesis(id_incidente);

CREATE INDEX idx_soluciones_incidente
    ON soluciones(id_incidente);

CREATE INDEX idx_soluciones_resultado
    ON soluciones(resultado);

CREATE INDEX idx_adjuntos_incidente
    ON adjuntos_incidente(id_incidente);


-- ============================================================
-- 7. TABLA: history
--
-- No se elimina esta tabla al recrear las cuatro tablas principales.
-- Si ya existe, se conserva y se ajusta usuario_id cuando sea necesario.
-- ============================================================

CREATE TABLE IF NOT EXISTS history (

    trace_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    session_id UUID NOT NULL,

    question TEXT NOT NULL,

    answer TEXT NOT NULL,

    usuario_id VARCHAR(6)
        CHECK (usuario_id ~ '^A[0-9]{5}$'),

    input_tokens INTEGER,

    output_tokens INTEGER,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    retrieved_contexts TEXT,

    is_ok BOOLEAN,

    feedback_comment TEXT,

    feedback_at TIMESTAMPTZ
);


-- ============================================================
-- 8. MIGRAR history.usuario_id SI LA TABLA YA EXISTÍA
--
-- Si era UUID, se conservan las filas, pero se establece NULL
-- para los identificadores antiguos que no tienen formato Axxxxx.
-- Si ya era VARCHAR(6), se conservan sus valores actuales.
-- ============================================================

DO $$
DECLARE
    tipo_usuario_id TEXT;
BEGIN
    SELECT data_type
    INTO tipo_usuario_id
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'history'
      AND column_name = 'usuario_id';

    IF tipo_usuario_id = 'uuid' THEN
        ALTER TABLE history
            ALTER COLUMN usuario_id DROP DEFAULT;

        ALTER TABLE history
            ALTER COLUMN usuario_id TYPE VARCHAR(6)
            USING NULL::VARCHAR(6);
    ELSIF tipo_usuario_id <> 'character varying' THEN
        RAISE EXCEPTION
            'Tipo inesperado para history.usuario_id: %',
            tipo_usuario_id;
    END IF;
END $$;

-- Garantizar que la validación del formato exista también
-- cuando history ya existía antes de ejecutar este script.
ALTER TABLE history
    DROP CONSTRAINT IF EXISTS history_usuario_id_formato_chk;

ALTER TABLE history
    ADD CONSTRAINT history_usuario_id_formato_chk
    CHECK (usuario_id ~ '^A[0-9]{5}$');


-- ============================================================
-- 9. COMENTARIOS DE history
-- ============================================================

COMMENT ON TABLE history IS
'Historial de consultas, respuestas, contexto recuperado y feedback del agente de IA.';

COMMENT ON COLUMN history.trace_id IS
'Identificador único de la ejecución del agente; puede vincularse con una traza de observabilidad.';

COMMENT ON COLUMN history.session_id IS
'Identificador que agrupa las consultas de una misma conversación.';

COMMENT ON COLUMN history.question IS
'Pregunta original enviada al agente por el colaborador.';

COMMENT ON COLUMN history.answer IS
'Respuesta final generada por el agente para la consulta.';

COMMENT ON COLUMN history.usuario_id IS
'Identificador seudonimizado del colaborador, con formato A seguido de cinco dígitos.';

COMMENT ON COLUMN history.input_tokens IS
'Cantidad de tokens de entrada reportada por el proveedor o modelo.';

COMMENT ON COLUMN history.output_tokens IS
'Cantidad de tokens de salida reportada por el proveedor o modelo.';

COMMENT ON COLUMN history.created_at IS
'Fecha y hora de registro de la consulta al agente.';

COMMENT ON COLUMN history.retrieved_contexts IS
'Resumen o referencias de los contextos recuperados para responder, como IDs de incidentes y soluciones.';

COMMENT ON COLUMN history.is_ok IS
'Feedback de utilidad: TRUE útil, FALSE no útil, NULL sin feedback.';

COMMENT ON COLUMN history.feedback_comment IS
'Comentario opcional del usuario para explicar o complementar su evaluación.';

COMMENT ON COLUMN history.feedback_at IS
'Fecha y hora en que se recibió el feedback del usuario.';


-- ============================================================
-- 10. ÍNDICES DE history
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_history_session_id
    ON history(session_id);

CREATE INDEX IF NOT EXISTS ix_history_usuario_id
    ON history(usuario_id);

CREATE INDEX IF NOT EXISTS ix_history_is_ok
    ON history(is_ok);

CREATE INDEX IF NOT EXISTS ix_history_created_at
    ON history(created_at);


-- ============================================================
-- 11. CONFIRMAR CAMBIOS
-- ============================================================

COMMIT;


-- ============================================================
-- 12. VERIFICAR TABLAS Y TIPOS DE LOS CAMPOS DE COLABORADORES
-- ============================================================

SELECT
    table_name AS tabla,
    column_name AS columna,
    data_type AS tipo_dato
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
      (table_name = 'incidentes'
       AND column_name = 'reportado_por_id')
      OR
      (table_name = 'hipotesis'
       AND column_name IN ('propuesto_por_id', 'evaluado_por_id'))
      OR
      (table_name = 'soluciones'
       AND column_name IN (
           'propuesto_por_id',
           'aplicado_por_id',
           'validado_por_id'
       ))
      OR
      (table_name = 'adjuntos_incidente'
       AND column_name = 'cargado_por_id')
      OR
      (table_name = 'history'
       AND column_name = 'usuario_id')
  )
ORDER BY table_name, column_name;
