# data_raw — RAW inmutable

.wav tal cual salen de la SD. **No se editan, no se renombran, no se borran.**
Solo se AÑADEN archivos nuevos (una SD que llega más tarde): `tar_files_input()` en
`_targets.R` los detecta y procesa únicamente esas ramas.

## Estructura: UNA CARPETA POR GRABADOR
AudioMoth NO mete el identificador del grabador en el nombre (solo la fecha),
así que el `recorder_id` se toma del nombre de la carpeta. Por eso:

    data_raw/AM01/20260501_060000.WAV   -> recorder_id = AM01
    data_raw/AM02/20260501_060000.WAV   -> recorder_id = AM02

## Datos de ejemplo incluidos (para la demo)
- AM01: 3 grabaciones de 10 s, con un HUECO de calendario (falta 06:20; lo
  detecta `qc_schedule_gaps()`, target `gaps`).
- AM02: 2 grabaciones de 10 s + 1 TRUNCADA de 3 s (dispara el QC de duración).

Cada WAV de ejemplo lleva un campo *Comment* simulado al estilo AudioMoth
(`Recorded at HH:MM:SS DD/MM/YYYY (UTC) ...`) en el bloque LIST/INFO (chunk
ICMT). Así `parse_metadata()` tiene una **segunda fuente** (la cabecera) para
validar contra el nombre, y el ejercicio de "romper la zona horaria" dispara el
aviso de discrepancia **sin necesidad de instalar `sonicscrewdriver`**. En datos
reales de AudioMoth ese campo ya viene de fábrica.

Las dos grabaciones de `nueva_descarga/AM01/` (06:40 y 06:50) NO están aquí a
propósito: se copian durante el ejercicio 2 de `practica.R`.
