BEGIN;

-- =========================================================
-- 1. INCIDENTES: 15 registros sintéticos
-- =========================================================

INSERT INTO public.incidentes (
    id,
    codigo,
    titulo,
    descripcion,
    componente,
    mensaje_error,
    estado,
    reportado_por_id
)
VALUES
(
    '10000000-0000-4000-8000-000000000001',
    'INC-0001',
    'Timeout en API de pagos',
    'Las solicitudes de pago exceden el tiempo máximo de respuesta durante periodos de alta demanda.',
    'API de pagos',
    'Read timed out',
    'resuelto',
    'A00001'
),
(
    '10000000-0000-4000-8000-000000000002',
    'INC-0002',
    'Error de autenticación OAuth',
    'Un consumidor de la API no puede autenticarse mediante OAuth.',
    'Autenticación',
    '401 Unauthorized',
    'resuelto',
    'A00002'
),
(
    '10000000-0000-4000-8000-000000000003',
    'INC-0003',
    'Certificado TLS vencido',
    'Una comunicación entre servicios falla por un certificado TLS vencido.',
    'Conectividad segura',
    'Certificate expired',
    'resuelto',
    'A00003'
),
(
    '10000000-0000-4000-8000-000000000004',
    'INC-0004',
    'Pool de conexiones agotado',
    'La aplicación no consigue conexiones disponibles con la base de datos.',
    'Base de datos',
    'Connection pool exhausted',
    'investigando',
    'A00001'
),
(
    '10000000-0000-4000-8000-000000000005',
    'INC-0005',
    'Acumulación de mensajes en cola',
    'La cola de mensajería acumula mensajes y aumenta el tiempo de procesamiento.',
    'Mensajería',
    'Consumer lag above threshold',
    'investigando',
    'A00002'
),
(
    '10000000-0000-4000-8000-000000000006',
    'INC-0006',
    'Fallo de despliegue por configuración',
    'El despliegue de una aplicación falla por parámetros de configuración ausentes.',
    'Despliegue',
    'Missing required configuration',
    'resuelto',
    'A00003'
),
(
    '10000000-0000-4000-8000-000000000007',
    'INC-0007',
    'Consulta SQL lenta',
    'Una consulta de búsqueda presenta tiempos de respuesta superiores al objetivo.',
    'Base de datos',
    'Query execution time exceeded threshold',
    'investigando',
    'A00001'
),
(
    '10000000-0000-4000-8000-000000000008',
    'INC-0008',
    'Bloqueo por política CORS',
    'Una aplicación web no puede consumir una API desde un origen diferente.',
    'API web',
    'CORS policy blocked request',
    'resuelto',
    'A00002'
),
(
    '10000000-0000-4000-8000-000000000009',
    'INC-0009',
    'Consumo elevado de memoria Java',
    'El proceso Java incrementa su consumo de memoria hasta afectar su estabilidad.',
    'Aplicación Java',
    'OutOfMemoryError',
    'investigando',
    'A00003'
),
(
    '10000000-0000-4000-8000-000000000010',
    'INC-0010',
    'Configuración inconsistente entre ambientes',
    'Una aplicación funciona en pruebas, pero presenta errores en producción debido a diferencias de configuración.',
    'Configuración',
    'Environment configuration mismatch',
    'resuelto',
    'A00001'
),
(
    '10000000-0000-4000-8000-000000000011',
    'INC-0011',
    'Operaciones duplicadas por reintentos',
    'Un mecanismo de reintentos genera operaciones duplicadas cuando no recibe respuesta a tiempo.',
    'Procesamiento de transacciones',
    'Duplicate transaction detected',
    'investigando',
    'A00002'
),
(
    '10000000-0000-4000-8000-000000000012',
    'INC-0012',
    'Fallo de resolución DNS',
    'Una aplicación no puede resolver el nombre de un servicio dependiente.',
    'Red',
    'UnknownHostException',
    'resuelto',
    'A00003'
),
(
    '10000000-0000-4000-8000-000000000013',
    'INC-0013',
    'Error 403 al acceder a un recurso',
    'Una cuenta de servicio recibe una respuesta 403 al invocar un recurso protegido.',
    'Autorización',
    '403 Forbidden',
    'investigando',
    'A00001'
),
(
    '10000000-0000-4000-8000-000000000014',
    'INC-0014',
    'Archivo batch con formato inválido',
    'El procesamiento de un archivo por lotes falla debido a registros con formato inesperado.',
    'Procesamiento batch',
    'Invalid record format',
    'resuelto',
    'A00002'
),
(
    '10000000-0000-4000-8000-000000000015',
    'INC-0015',
    'Latencia elevada entre microservicios',
    'Las llamadas encadenadas entre servicios presentan latencia elevada.',
    'Microservicios',
    'Upstream request timeout',
    'investigando',
    'A00003'
)
ON CONFLICT (id) DO NOTHING;


-- =========================================================
-- 2. HIPÓTESIS: 20 registros sintéticos
-- =========================================================

INSERT INTO public.hipotesis (
    id,
    id_incidente,
    descripcion,
    evidencia,
    estado,
    propuesto_por_id,
    evaluado_por_id
)
VALUES
(
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'El timeout podría deberse a un tiempo de espera insuficiente en el cliente.',
    'Los registros muestran solicitudes que superan el límite configurado.',
    'confirmada',
    'A00001',
    'A00002'
),
(
    '20000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    'La saturación del servicio podría estar relacionada con un incremento de solicitudes concurrentes.',
    'Se observan picos de tráfico durante el periodo del incidente.',
    'confirmada',
    'A00002',
    'A00003'
),
(
    '20000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002',
    'El cliente podría estar utilizando un token expirado.',
    'La respuesta de autenticación indica que el token no es válido.',
    'confirmada',
    'A00003',
    'A00001'
),
(
    '20000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000002',
    'La configuración de audiencia del token podría no coincidir con la API.',
    'La configuración del consumidor y la del servicio presentan diferencias.',
    'descartada',
    'A00001',
    'A00002'
),
(
    '20000000-0000-4000-8000-000000000005',
    '10000000-0000-4000-8000-000000000003',
    'El certificado presentado por el servicio podría haber vencido.',
    'La inspección del certificado muestra una fecha de expiración pasada.',
    'confirmada',
    'A00002',
    'A00003'
),
(
    '20000000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000004',
    'Las conexiones podrían no liberarse correctamente después de cada operación.',
    'Las métricas muestran un aumento sostenido de conexiones activas.',
    'pendiente',
    'A00003',
    NULL
),
(
    '20000000-0000-4000-8000-000000000007',
    '10000000-0000-4000-8000-000000000004',
    'El límite del pool podría ser insuficiente para la carga concurrente.',
    'Se reporta agotamiento del pool durante picos de solicitudes.',
    'pendiente',
    'A00001',
    NULL
),
(
    '20000000-0000-4000-8000-000000000008',
    '10000000-0000-4000-8000-000000000005',
    'La capacidad de procesamiento de los consumidores podría ser inferior a la tasa de llegada de mensajes.',
    'El retraso de consumo aumenta mientras continúa la publicación.',
    'pendiente',
    'A00002',
    NULL
),
(
    '20000000-0000-4000-8000-000000000009',
    '10000000-0000-4000-8000-000000000006',
    'Una variable de entorno obligatoria podría faltar en el ambiente de destino.',
    'Los registros de inicio indican que falta un parámetro requerido.',
    'confirmada',
    'A00003',
    'A00001'
),
(
    '20000000-0000-4000-8000-000000000010',
    '10000000-0000-4000-8000-000000000007',
    'La consulta podría no utilizar un índice apropiado.',
    'El plan de ejecución presenta un recorrido extenso de registros.',
    'pendiente',
    'A00001',
    NULL
),
(
    '20000000-0000-4000-8000-000000000011',
    '10000000-0000-4000-8000-000000000007',
    'El volumen de datos procesado podría haber aumentado considerablemente.',
    'El tiempo de ejecución se incrementa con el volumen de registros.',
    'inconclusa',
    'A00002',
    'A00003'
),
(
    '20000000-0000-4000-8000-000000000012',
    '10000000-0000-4000-8000-000000000008',
    'El origen de la aplicación web podría no estar autorizado en la configuración CORS.',
    'El navegador informa que el origen no está permitido.',
    'confirmada',
    'A00003',
    'A00001'
),
(
    '20000000-0000-4000-8000-000000000013',
    '10000000-0000-4000-8000-000000000009',
    'Podría existir una retención excesiva de objetos en memoria.',
    'El consumo de memoria crece durante la ejecución.',
    'pendiente',
    'A00001',
    NULL
),
(
    '20000000-0000-4000-8000-000000000014',
    '10000000-0000-4000-8000-000000000010',
    'La aplicación podría utilizar valores diferentes de configuración entre ambientes.',
    'La comparación de parámetros revela diferencias.',
    'confirmada',
    'A00002',
    'A00003'
),
(
    '20000000-0000-4000-8000-000000000015',
    '10000000-0000-4000-8000-000000000011',
    'El sistema podría volver a procesar una solicitud sin verificar si ya fue ejecutada.',
    'Se encuentran solicitudes repetidas asociadas al mismo flujo.',
    'pendiente',
    'A00003',
    NULL
),
(
    '20000000-0000-4000-8000-000000000016',
    '10000000-0000-4000-8000-000000000012',
    'El registro DNS del servicio podría ser incorrecto o no estar disponible.',
    'La resolución del nombre falla desde el ambiente afectado.',
    'confirmada',
    'A00001',
    'A00002'
),
(
    '20000000-0000-4000-8000-000000000017',
    '10000000-0000-4000-8000-000000000013',
    'La identidad de servicio podría carecer de un permiso requerido.',
    'La API devuelve 403 al invocar el recurso protegido.',
    'pendiente',
    'A00002',
    NULL
),
(
    '20000000-0000-4000-8000-000000000018',
    '10000000-0000-4000-8000-000000000014',
    'El archivo podría contener campos obligatorios vacíos o delimitadores incorrectos.',
    'El proceso identifica registros que no cumplen el formato esperado.',
    'confirmada',
    'A00003',
    'A00001'
),
(
    '20000000-0000-4000-8000-000000000019',
    '10000000-0000-4000-8000-000000000015',
    'La latencia podría acumularse debido a llamadas síncronas encadenadas.',
    'Las trazas muestran demoras sucesivas entre servicios.',
    'pendiente',
    'A00001',
    NULL
),
(
    '20000000-0000-4000-8000-000000000020',
    '10000000-0000-4000-8000-000000000015',
    'Un servicio dependiente podría estar experimentando degradación.',
    'Las métricas de latencia del servicio dependiente son elevadas.',
    'inconclusa',
    'A00002',
    'A00003'
)
ON CONFLICT (id) DO NOTHING;


-- =========================================================
-- 3. SOLUCIONES: 20 registros sintéticos
-- =========================================================

INSERT INTO public.soluciones (
    id,
    id_incidente,
    id_hipotesis,
    descripcion,
    estado,
    resultado,
    propuesto_por_id,
    aplicado_por_id,
    validado_por_id
)
VALUES
(
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    'Ajustar el tiempo de espera del cliente dentro de límites aprobados y revisar los tiempos de respuesta del servicio.',
    'aplicada',
    'efectiva',
    'A00001',
    'A00002',
    'A00003'
),
(
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000002',
    'Revisar la capacidad del servicio, las métricas de concurrencia y las políticas de escalamiento.',
    'propuesta',
    'pendiente',
    'A00002',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000003',
    'Renovar el token mediante el flujo de autenticación autorizado y verificar su expiración.',
    'aplicada',
    'efectiva',
    'A00003',
    'A00001',
    'A00002'
),
(
    '30000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000004',
    'Modificar la audiencia del token sin evidencia suficiente de que sea la causa del incidente.',
    'retirada',
    'no_efectiva',
    'A00001',
    'A00002',
    'A00003'
),
(
    '30000000-0000-4000-8000-000000000005',
    '10000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000005',
    'Renovar el certificado TLS mediante el procedimiento aprobado y comprobar la cadena de confianza.',
    'aplicada',
    'efectiva',
    'A00002',
    'A00003',
    'A00001'
),
(
    '30000000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000004',
    '20000000-0000-4000-8000-000000000006',
    'Revisar el cierre de conexiones y comprobar que las operaciones liberen los recursos correctamente.',
    'propuesta',
    'pendiente',
    'A00003',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000007',
    '10000000-0000-4000-8000-000000000004',
    '20000000-0000-4000-8000-000000000007',
    'Evaluar el dimensionamiento del pool con métricas de carga antes de modificar sus límites.',
    'propuesta',
    'pendiente',
    'A00001',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000008',
    '10000000-0000-4000-8000-000000000005',
    '20000000-0000-4000-8000-000000000008',
    'Revisar la capacidad de los consumidores, el retraso de procesamiento y la posibilidad de escalar de forma controlada.',
    'propuesta',
    'pendiente',
    'A00002',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000009',
    '10000000-0000-4000-8000-000000000006',
    '20000000-0000-4000-8000-000000000009',
    'Completar la configuración requerida en el ambiente de destino y validar el inicio de la aplicación.',
    'aplicada',
    'efectiva',
    'A00003',
    'A00001',
    'A00002'
),
(
    '30000000-0000-4000-8000-000000000010',
    '10000000-0000-4000-8000-000000000007',
    '20000000-0000-4000-8000-000000000010',
    'Analizar el plan de ejecución y evaluar índices adecuados con pruebas controladas.',
    'propuesta',
    'pendiente',
    'A00001',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000011',
    '10000000-0000-4000-8000-000000000007',
    '20000000-0000-4000-8000-000000000011',
    'Medir el volumen procesado y revisar la necesidad de paginación o una consulta más selectiva.',
    'propuesta',
    'pendiente',
    'A00002',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000012',
    '10000000-0000-4000-8000-000000000008',
    '20000000-0000-4000-8000-000000000012',
    'Configurar los orígenes permitidos de acuerdo con la política de seguridad y verificar la solicitud preflight.',
    'aplicada',
    'efectiva',
    'A00003',
    'A00001',
    'A00002'
),
(
    '30000000-0000-4000-8000-000000000013',
    '10000000-0000-4000-8000-000000000009',
    '20000000-0000-4000-8000-000000000013',
    'Analizar el perfil de memoria y los registros de recolección de basura para identificar retenciones.',
    'propuesta',
    'pendiente',
    'A00001',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000014',
    '10000000-0000-4000-8000-000000000010',
    '20000000-0000-4000-8000-000000000014',
    'Comparar las variables de configuración entre ambientes y estandarizar su gestión.',
    'aplicada',
    'efectiva',
    'A00002',
    'A00003',
    'A00001'
),
(
    '30000000-0000-4000-8000-000000000015',
    '10000000-0000-4000-8000-000000000011',
    '20000000-0000-4000-8000-000000000015',
    'Evaluar un mecanismo de idempotencia para evitar que una misma operación se ejecute dos veces.',
    'propuesta',
    'pendiente',
    'A00003',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000016',
    '10000000-0000-4000-8000-000000000012',
    '20000000-0000-4000-8000-000000000016',
    'Verificar la resolución DNS desde el ambiente afectado y corregir el registro o la configuración pertinente.',
    'aplicada',
    'efectiva',
    'A00001',
    'A00002',
    'A00003'
),
(
    '30000000-0000-4000-8000-000000000017',
    '10000000-0000-4000-8000-000000000013',
    '20000000-0000-4000-8000-000000000017',
    'Revisar los permisos efectivos de la identidad de servicio y solicitar únicamente los accesos necesarios.',
    'propuesta',
    'pendiente',
    'A00002',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000018',
    '10000000-0000-4000-8000-000000000014',
    '20000000-0000-4000-8000-000000000018',
    'Validar el esquema del archivo antes del procesamiento y reportar los registros que no cumplan el formato.',
    'aplicada',
    'efectiva',
    'A00003',
    'A00001',
    'A00002'
),
(
    '30000000-0000-4000-8000-000000000019',
    '10000000-0000-4000-8000-000000000015',
    '20000000-0000-4000-8000-000000000019',
    'Analizar las trazas distribuidas y los tiempos de cada dependencia para localizar la acumulación de latencia.',
    'propuesta',
    'pendiente',
    'A00001',
    NULL,
    NULL
),
(
    '30000000-0000-4000-8000-000000000020',
    '10000000-0000-4000-8000-000000000015',
    '20000000-0000-4000-8000-000000000020',
    'Medir la salud y latencia del servicio dependiente antes de aplicar cambios de capacidad o reintentos.',
    'propuesta',
    'pendiente',
    'A00002',
    NULL,
    NULL
)
ON CONFLICT (id) DO NOTHING;


-- =========================================================
-- 4. ADJUNTOS: 10 referencias a archivos de prueba
-- =========================================================

INSERT INTO public.adjuntos_incidente (
    id,
    id_incidente,
    nombre_archivo,
    ubicacion_archivo,
    texto_extraido,
    cargado_por_id
)
VALUES
(
    '40000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'logs_timeout_api.txt',
    'test-data/incidentes/INC-0001/logs_timeout_api.txt',
    'Ejemplo de log: solicitud a API de pagos superó el tiempo de espera configurado.',
    'A00001'
),
(
    '40000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    'error_oauth.json',
    'test-data/incidentes/INC-0002/error_oauth.json',
    'Ejemplo de respuesta: 401 Unauthorized. Revisar expiración y audiencia del token.',
    'A00002'
),
(
    '40000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000003',
    'detalle_certificado.txt',
    'test-data/incidentes/INC-0003/detalle_certificado.txt',
    'Ejemplo de diagnóstico: certificado TLS expirado.',
    'A00003'
),
(
    '40000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004',
    'metricas_pool.csv',
    'test-data/incidentes/INC-0004/metricas_pool.csv',
    'Ejemplo de métricas: conexiones activas elevadas y disponibilidad insuficiente en el pool.',
    'A00001'
),
(
    '40000000-0000-4000-8000-000000000005',
    '10000000-0000-4000-8000-000000000005',
    'metricas_cola.txt',
    'test-data/incidentes/INC-0005/metricas_cola.txt',
    'Ejemplo de diagnóstico: retraso de consumidores creciente.',
    'A00002'
),
(
    '40000000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000006',
    'error_despliegue.log',
    'test-data/incidentes/INC-0006/error_despliegue.log',
    'Ejemplo de log: falta una variable de configuración obligatoria.',
    'A00003'
),
(
    '40000000-0000-4000-8000-000000000007',
    '10000000-0000-4000-8000-000000000007',
    'plan_consulta.txt',
    'test-data/incidentes/INC-0007/plan_consulta.txt',
    'Ejemplo de análisis: plan de ejecución con recorrido de registros de alto costo.',
    'A00001'
),
(
    '40000000-0000-4000-8000-000000000008',
    '10000000-0000-4000-8000-000000000008',
    'error_cors.txt',
    'test-data/incidentes/INC-0008/error_cors.txt',
    'Ejemplo de error: el origen de la aplicación no está permitido por la política CORS.',
    'A00002'
),
(
    '40000000-0000-4000-8000-000000000009',
    '10000000-0000-4000-8000-000000000009',
    'memoria_java.log',
    'test-data/incidentes/INC-0009/memoria_java.log',
    'Ejemplo de log: consumo de memoria elevado durante la ejecución de la aplicación Java.',
    'A00003'
),
(
    '40000000-0000-4000-8000-000000000010',
    '10000000-0000-4000-8000-000000000010',
    'comparacion_ambientes.txt',
    'test-data/incidentes/INC-0010/comparacion_ambientes.txt',
    'Ejemplo de análisis: diferencias entre parámetros de configuración de dos ambientes.',
    'A00001'
)
ON CONFLICT (id) DO NOTHING;


COMMIT;