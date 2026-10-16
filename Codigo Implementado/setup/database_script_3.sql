
-- ============================================================
-- PROYECTO: Agente de IA para asistencia técnica
-- FINALIDAD:
-- Asignar fechas de creación aleatorias y cronológicamente
-- coherentes a los datos sintéticos del piloto.
--
-- REGLAS:
-- 1. Incidentes: últimos 90 días.
-- 2. Hipótesis: desde la fecha del incidente hasta 5 días después.
-- 3. Soluciones: desde la fecha del incidente y de su hipótesis
--    asociada (si existe), hasta 5 días después.
-- 4. Adjuntos: desde la fecha del incidente hasta 3 días después.
-- 5. History no se modifica.
--
-- IMPORTANTE:
-- Este script actualiza TODOS los registros de estas cuatro
-- tablas, no solo los datos de prueba. Usar en entorno de pruebas.
-- Si se vuelve a ejecutar, generará nuevas fechas aleatorias.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. INCIDENTES
-- Distribuir los incidentes aleatoriamente en los últimos 90 días.
-- ============================================================

UPDATE public.incidentes
SET fecha_creacion =
    NOW() - (RANDOM() * INTERVAL '90 days');


-- ============================================================
-- 2. HIPÓTESIS
-- Cada hipótesis se crea entre el día del incidente y los
-- cinco días posteriores.
-- ============================================================

UPDATE public.hipotesis AS h
SET fecha_creacion =
    i.fecha_creacion
    + (RANDOM() * INTERVAL '5 days')
FROM public.incidentes AS i
WHERE h.id_incidente = i.id;


-- ============================================================
-- 3. SOLUCIONES
-- La solución se crea después del incidente y, si tiene una
-- hipótesis asociada, después de la fecha de esa hipótesis.
-- Se agregan entre cero y cinco días de espera.
-- ============================================================

UPDATE public.soluciones AS s
SET fecha_creacion =
    x.fecha_base + (RANDOM() * INTERVAL '5 days')
FROM (
    SELECT
        s2.id AS id_solucion,
        GREATEST(
            i.fecha_creacion,
            COALESCE(h.fecha_creacion, i.fecha_creacion)
        ) AS fecha_base
    FROM public.soluciones AS s2
    INNER JOIN public.incidentes AS i
        ON i.id = s2.id_incidente
    LEFT JOIN public.hipotesis AS h
        ON h.id = s2.id_hipotesis
) AS x
WHERE s.id = x.id_solucion;


-- ============================================================
-- 4. ADJUNTOS
-- Los archivos se registran desde el día del incidente hasta
-- tres días después.
-- ============================================================

UPDATE public.adjuntos_incidente AS a
SET fecha_creacion =
    i.fecha_creacion
    + (RANDOM() * INTERVAL '3 days')
FROM public.incidentes AS i
WHERE a.id_incidente = i.id;


-- AJUSTES EN HISTORY : INICIO

ALTER TABLE "history"
RENAME COLUMN "usuario_id" TO "user";

ALTER TABLE "history"
ALTER COLUMN "user"
SET DATA TYPE varchar(255) USING "user"::varchar(255);

ALTER TABLE history
DROP CONSTRAINT history_usuario_id_check;

ALTER TABLE history
ADD CONSTRAINT history_usuario_id_check
CHECK (
    "user" ~ '^A[0-9]{5}$'
    OR "user" ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);

ALTER TABLE public.history
DROP CONSTRAINT history_usuario_id_formato_chk;

-- AJUSTES EN HISTORY : FIN


COMMIT;


-- ============================================================
-- 5. VERIFICAR LA CRONOLOGÍA
-- Mostrar incidentes con sus hipótesis, soluciones y fechas.
-- ============================================================

SELECT
    i.codigo AS codigo_incidente,
    i.titulo AS incidente,
    i.fecha_creacion AS fecha_incidente,
    h.fecha_creacion AS fecha_hipotesis,
    s.fecha_creacion AS fecha_solucion,
    a.fecha_creacion AS fecha_adjunto
FROM public.incidentes AS i
LEFT JOIN public.hipotesis AS h
    ON h.id_incidente = i.id
LEFT JOIN public.soluciones AS s
    ON s.id_incidente = i.id
LEFT JOIN public.adjuntos_incidente AS a
    ON a.id_incidente = i.id
ORDER BY
    i.fecha_creacion DESC,
    h.fecha_creacion,
    s.fecha_creacion;
