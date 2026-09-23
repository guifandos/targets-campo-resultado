# fototrampeo/_targets.R
# -------------------------------------------------------------------
# Segundo proyecto del repo: el MISMO esqueleto con otro sensor.
# De las tarjetas de las cámaras trampa a una tabla de tasas de detección.
#
# Desde la carpeta raíz del proyecto (no hace falta setwd()):
#   Sys.setenv(TAR_PROJECT = "fototrampeo")   # ver _targets.yaml
#   targets::tar_make()
#   Sys.unsetenv("TAR_PROJECT")                # volver al caso acústico
#
# Las rutas son relativas a la raíz del repo.
# -------------------------------------------------------------------

library(targets)
library(tarchetypes)  # para tar_files_input()

# Funciones propias + el guardarraíl de claves del caso acústico
tar_source(c("fototrampeo/R", "R/consolidate.R"))

tar_option_set(packages = "dplyr")

# --- Parámetros del análisis (decisiones, no verdades) --------------
ct_dir     <- "fototrampeo/data_raw"  # una carpeta por cámara (RAW, no se toca)
camera_tz  <- "Europe/Madrid"         # zona horaria configurada en las cámaras
min_conf   <- 0.5                     # confianza mínima del detector
indep_min  <- 30                      # minutos entre eventos independientes
# -------------------------------------------------------------------

list(
  # 1. Ingesta: una rama por tarjeta
  tar_files_input(tag_files, list_tag_files(ct_dir)),
  tar_target(deploy_file, "fototrampeo/data/despliegues.csv", format = "file"),
  tar_target(deployments, read_deployments(deploy_file, tz = camera_tz)),
  tar_target(tags, parse_tags(tag_files, tz = camera_tz),
             pattern = map(tag_files)),

  # 2. QC: reloj, fotos vacías y confianza del detector
  tar_target(tags_qc, qc_clock(tags, deployments, min_conf = min_conf),
             pattern = map(tags)),
  tar_target(clock_report, clock_summary(tags_qc)),

  # 3. Esfuerzo y eventos independientes (una rama por tarjeta)
  tar_target(effort, camera_effort(tags_qc, deployments),
             pattern = map(tags_qc)),
  tar_target(events, independent_events(tags_qc, threshold_min = indep_min),
             pattern = map(tags_qc)),

  # 4. Tabla final: cámara x especie, con ceros
  tar_target(final_table, detection_rates(events, effort, deployments)),
  tar_target(
    final_csv,
    {
      out <- "fototrampeo/output/tasas_deteccion.csv"
      write.csv(final_table, out, row.names = FALSE)
      out
    },
    format = "file"
  )
)
