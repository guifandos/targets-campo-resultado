# ============================================================
# Pipelines reproducibles del campo al resultado con targets
# II Jornadas de Ecoinformática de la AEET · Sevilla, 1 de octubre de 2026
#
# Ejecuta cada línea con Ctrl+Enter (Cmd+Enter en macOS), o
# selecciona un bloque y pulsa Ctrl+Enter para correrlo entero.
#
# ANTES del taller: ejecuta check_setup.R una vez.
# ============================================================


# ── REINICIAR EL PIPELINE DESDE CERO ────────────────────────────────────────
# Si algo se queda raro, vuelve al estado inicial con:
#
#   targets::tar_destroy()   # borra _targets/ y fuerza recálculo total
#   targets::tar_make()
#
# y comprueba que data_raw/AM01/ solo tiene sus 3 archivos originales.
# ─────────────────────────────────────────────────────────────────────────────


# ============================================================
# EJERCICIO 1 (4 min)
# Mira el pipeline antes de ejecutarlo
# ============================================================

# ¿Qué targets hay y qué comando tiene cada uno? (sin dependencias extra)
targets::tar_manifest()

# El grafo interactivo (necesita el paquete visNetwork):
# targets::tar_visnetwork()

# Ejecuta el pipeline completo:
targets::tar_make()

# La tabla final y un resultado intermedio leído desde la caché:
tabla <- read.csv("output/tabla_analisis.csv")
nrow(tabla)                  # esperado: 5 (6 grabaciones, 1 truncada no pasa QC)
targets::tar_read(gaps)      # esperado: 1 hueco en AM01 (06:10 -> 06:30)

# Cada archivo es una RAMA. ¿Cuántas ramas tiene cada etapa?
targets::tar_progress_branches()


# ============================================================
# EJERCICIO 2 (7 min)
# Llega una SD nueva: ¿qué se recalcula?
# ============================================================

# PREDICE ANTES DE EJECUTAR: si añades 2 grabaciones nuevas de AM01,
# ¿cuántas ramas de meta_raw se ejecutarán? ¿Y de indices?

# PASO 1 — Copia la SD nueva a data_raw/AM01/ (data_raw es de solo AÑADIR):
file.copy(list.files("nueva_descarga/AM01", pattern = "\\.WAV$",
                     full.names = TRUE),
          "data_raw/AM01")

# PASO 2 — Ejecuta y comprueba:
targets::tar_make()
targets::tar_progress_branches()
#   esperado: en cada etapa, 2 ramas 'completed' y 6 'skipped'

nrow(read.csv("output/tabla_analisis.csv"))   # esperado: 7

# PREGUNTA: tar_files_input() vuelve a listar data_raw/ cada vez que se
# lee _targets.R. ¿Qué pasaría si audio_files fuera un tar_target()
# normal que llama a list_audio()? (Lo compruebas en el Extra C.)

# ── RESTAURACIÓN ────────────────────────────────────────────
file.remove(file.path("data_raw/AM01",
                      c("20260501_064000.WAV", "20260501_065000.WAV")))
targets::tar_make()
# La tabla vuelve a 5 filas.
# ────────────────────────────────────────────────────────────


# ============================================================
# EJERCICIO 3 (demo en sala; repítelo en casa)
# Cambia un umbral de QC: predice qué se recalcula
# ============================================================

# PASO 1 — Abre R/qc.R y localiza la línea:
#             qc_flag <- function(meta, expected_dur_s = NULL, tol_frac = 0.05) {
#           Cámbiala a:
#             qc_flag <- function(meta, expected_dur_s = NULL, tol_frac = 0.75) {
#           Guarda el archivo (Ctrl+S).

# PREDICE ANTES DE EJECUTAR: ¿cuántas ramas de meta_raw, meta_qc e
# indices se volverán a calcular?
# targets también puede decirte qué targets están desactualizados
# (a nivel de target, no de rama). ¿Aparece meta_raw?
targets::tar_outdated()

# PASO 2 — Ejecuta y comprueba:
targets::tar_make()
targets::tar_progress_branches()
#   esperado: meta_raw  -> 6 skipped      (el parseo no depende de qc.R)
#             meta_qc   -> 6 completed    (la función cambió)
#             indices   -> 1 completed, 5 skipped

nrow(read.csv("output/tabla_analisis.csv"))   # esperado: 6

# PREGUNTA: las 6 ramas de meta_qc se recalcularon, pero solo 1 de
# indices. ¿Por qué? Pista: targets no solo mira el código, también
# compara el VALOR que devuelve cada rama.

# ── RESTAURACIÓN ────────────────────────────────────────────
# En R/qc.R vuelve a tol_frac = 0.05, guarda y ejecuta:
targets::tar_make()
# El resumen vuelve a PASAN QC: 5 / 6.
# ────────────────────────────────────────────────────────────


# ============================================================
# EXTRAS PARA CASA
# ============================================================

# ── EXTRA A · Zona horaria incorrecta ───────────────────────
# En _targets.R cambia  recorder_tz <- "UTC"  por  "America/New_York",
# guarda y ejecuta:
#   targets::tar_make()
# Salta un aviso de DISCREPANCIA nombre vs cabecera por cada archivo.
# targets guarda los avisos de cada rama en sus metadatos:
#   targets::tar_meta(fields = warnings, complete_only = TRUE)
# Mira las columnas dt_name y dt_header: ambas dicen 06:00, pero en
# zonas horarias distintas son instantes distintos.
#   meta <- targets::tar_read(meta_qc)
#   meta[, c("filename", "dt_name", "dt_header", "name_vs_header_mismatch")]
# Restaura "UTC" y vuelve a ejecutar tar_make().

# ── EXTRA B · Un join que infla filas ───────────────────────
# En _targets.R cambia  "data/sites.csv"  por  "data/sites_duplicate.csv",
# guarda y ejecuta tar_make(). La tabla pasa de 5 a 7 filas y salta el
# aviso de consolidate(). ¿Qué grabador está duplicado?
#   sites_dup <- read.csv("data/sites_duplicate.csv")
#   sites_dup[duplicated(sites_dup$recorder_id), ]
# Restaura "data/sites.csv" y vuelve a ejecutar tar_make().

# ── EXTRA C · Rompe la detección de archivos nuevos ─────────
# En _targets.R sustituye
#   tar_files_input(audio_files, list_audio(audio_dir)),
# por
#   tar_target(audio_files, list_audio(audio_dir)),
# ejecuta tar_make() y repite el Ejercicio 2. ¿Aparecen los archivos
# nuevos en la tabla? ¿Por qué no? (Pista: ¿de qué depende ese target?)
# Restaura tar_files_input(), borra las copias de data_raw/AM01/ y ejecuta
# tar_make().

# ── EXTRA D · Tu propio proyecto ────────────────────────────
# Sustituye data_raw/ por tus carpetas (una por grabador), ajusta
# data/sites.csv y los parámetros del principio de _targets.R, y
# ejecuta tar_make(). Para datos reales, pasa fun = compute_indices
# a indices_if_pass() o conecta BirdNET (ver R/indices.R).


# ── EXTRA E · El mismo esqueleto con fototrampeo ────────────
# Segundo proyecto de targets en el mismo repo (ver _targets.yaml y
# fototrampeo/README.md). Se cambia de proyecto sin setwd():
#   Sys.setenv(TAR_PROJECT = "fototrampeo")
#   targets::tar_make()
#   read.csv("fototrampeo/output/tasas_deteccion.csv")   # 12 filas
#   targets::tar_read(effort)   # CT03: 3.49 días (reloj reiniciado)
# Ahora en fototrampeo/_targets.R cambia  indep_min <- 30  por  60,
# guarda y ejecuta:
#   targets::tar_outdated()          # solo events, final_table, final_csv
#   targets::tar_make()
#   targets::tar_progress_branches() # events: 3 completed; el resto skipped
#   sum(read.csv("fototrampeo/output/tasas_deteccion.csv")$n_events)  # 64 -> 45
# Restaura 30, ejecuta tar_make() y vuelve al caso acústico:
#   Sys.unsetenv("TAR_PROJECT")


# ── Entorno con el que has ejecutado la práctica ────────────
sessionInfo()
