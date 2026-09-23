# _targets.R
# -------------------------------------------------------------------
# Pipeline reproducible del flujo ecoacústico (de la SD a la tabla).
# Ejecuta con:  targets::tar_make()
# Visualiza con: targets::tar_visnetwork()   (requiere 'visNetwork')
#                targets::tar_manifest()     (sin dependencias extra)
#
# 'targets' recalcula SOLO lo que cambia. Si editas R/qc.R, recorre de ahí
# en adelante; lo anterior se reutiliza de caché. Eso es lo que hace que el
# pipeline sobreviva a 3 temporadas de campo y al relevo de becarios.
#
# Cada archivo de audio es una RAMA (dynamic branching): si llega una SD
# nueva, solo se procesan los archivos nuevos; si cambia un umbral de QC,
# solo se recalculan las ramas cuyo resultado cambia.
# -------------------------------------------------------------------

library(targets)
library(tarchetypes)  # para tar_files_input()

# Cargar todas las funciones de R/
tar_source("R")

tar_option_set(
  packages = c("tuneR", "seewave", "dplyr")
)

# --- Parámetros del proyecto (edítalos para tu campaña) -------------
audio_dir          <- "data_raw"   # carpeta con los .wav (RAW, no se toca)
recorder_tz        <- "UTC"        # zona horaria con la que graba el aparato
expected_dur_s     <- 10           # duración nominal por archivo
expected_interval  <- 10           # minutos entre grabaciones programadas
# -------------------------------------------------------------------

list(
  # 1. Ingesta: localizar archivos de audio.
  #    tar_files_input() lista data_raw/ cada vez que se lee este script
  #    (tar_make(), tar_outdated(), tar_visnetwork()...) y crea DOS targets:
  #      audio_files_files -> el vector de rutas
  #      audio_files       -> una rama por archivo con format = "file":
  #                           targets vigila el CONTENIDO de cada WAV
  #    Así detecta archivos nuevos y archivos modificados.
  tar_files_input(audio_files, list_audio(audio_dir)),

  # 2. Metadatos: nombre + cabecera, con validación cruzada (una rama/archivo)
  tar_target(meta_raw, parse_one(audio_files, tz = recorder_tz),
             pattern = map(audio_files)),

  # 3. QC: marcar problemáticos (una rama/archivo) y resumir el conjunto
  tar_target(meta_qc, qc_flag(meta_raw, expected_dur_s = expected_dur_s),
             pattern = map(meta_raw)),
  tar_target(qc_report, qc_summary(meta_qc)),
  tar_target(gaps, qc_schedule_gaps(meta_qc, expected_interval)),

  # 4. Procesado (una rama/archivo; los que no pasan QC devuelven NULL)
  #    Demo sin dependencias extra; en datos reales pasa
  #    fun = compute_indices (soundecology) a indices_if_pass().
  tar_target(indices, indices_if_pass(audio_files, meta_qc),
             pattern = map(audio_files, meta_qc)),
  #    BirdNET (descomenta si lo usas). Ojo: así escrito depende solo de la
  #    RUTA de la carpeta, no de su contenido; para que detecte archivos
  #    nuevos, haz que dependa de 'audio_files'.
  # tar_target(birdnet_csv, run_birdnet(audio_dir, "output/birdnet")),
  # tar_target(detections, read_birdnet_out(birdnet_csv)),

  # 5. Diseño de muestreo (una fila por grabador/despliegue)
  tar_target(sites_file, "data/sites.csv", format = "file"),
  tar_target(sites, read.csv(sites_file, stringsAsFactors = FALSE)),

  # 6. Consolidación final -> tabla tidy lista para modelar
  tar_target(
    final_table,
    consolidate(indices, meta_qc, sites,
                by_results = "file", by_sites = "recorder_id")
  ),
  tar_target(
    final_csv,
    {
      out <- "output/tabla_analisis.csv"
      write.csv(final_table, out, row.names = FALSE)
      out
    },
    format = "file"
  )
)
