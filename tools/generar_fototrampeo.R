# tools/generar_fototrampeo.R
# -------------------------------------------------------------------
# Genera los datos SINTÉTICOS del caso de fototrampeo (fototrampeo/):
#   - fototrampeo/data_raw/CTxx/etiquetas.csv  (una tabla por tarjeta SD)
#   - fototrampeo/data/despliegues.csv         (diseño de muestreo)
# NO forma parte del pipeline: se ejecuta una vez y queda aquí para que
# los datos sean reproducibles.
#
#   Rscript tools/generar_fototrampeo.R
#
# Cada etiquetas.csv imita la tabla que exportas tras pasar el detector
# (p. ej. MegaDetector) y clasificar/etiquetar las fotos: una fila por
# foto, con la fecha en formato EXIF ("YYYY:MM:DD HH:MM:SS").
# Trampas incluidas a propósito:
#   - disparos en falso (sin especie, confianza baja del detector)
#   - revisitas a 35-55 min (cuentan distinto con umbral de 30 o 60 min)
#   - CT03 cambia de pilas el 6 de mayo y su reloj vuelve a 2000-01-01
# -------------------------------------------------------------------

set.seed(2026)

tz        <- "Europe/Madrid"
out_root  <- "fototrampeo"
overwrite <- FALSE

deployments <- data.frame(
  camera_id    = c("CT01", "CT02", "CT03"),
  site         = c("RIO-01", "RIO-02", "RIO-03"),
  lat          = c(40.124, 40.131, 40.138),
  lon          = c(-3.455, -3.461, -3.468),
  habitat      = c("ripario", "matorral", "pastizal"),
  deploy_start = "2026-05-01 10:00:00",
  deploy_end   = "2026-05-15 10:00:00",
  stringsAsFactors = FALSE
)

# Visitas esperadas en 14 días por cámara y especie (0 = nunca pasa por ahí)
visits <- list(
  CT01 = c("Sus scrofa" = 8, "Vulpes vulpes" = 6, "Capreolus capreolus" = 4, "Meles meles" = 3),
  CT02 = c("Sus scrofa" = 5, "Vulpes vulpes" = 7, "Capreolus capreolus" = 6, "Meles meles" = 1),
  CT03 = c("Sus scrofa" = 3, "Vulpes vulpes" = 5, "Capreolus capreolus" = 7, "Meles meles" = 0)
)

# Horas de actividad (simplificadas) por especie
active_hours <- list(
  "Sus scrofa"          = c(21:23, 0:4),
  "Vulpes vulpes"       = c(19:23, 0:6),
  "Capreolus capreolus" = c(5:8, 19:22),
  "Meles meles"         = c(22:23, 0:3)
)

# CT03: momento del cambio de pilas (a partir de aquí el reloj se reinicia)
battery_change <- as.POSIXct("2026-05-06 09:00:00", tz = tz)
clock_reset_to <- as.POSIXct("2000-01-01 00:00:00", tz = tz)

draw_time <- function(hours, start, end) {
  repeat {
    day <- sample(0:13, 1L)
    t <- start + day * 86400 + (sample(hours, 1L) - 10) * 3600 + runif(1L, 0, 3600)
    if (t > start && t < end) return(t)
  }
}

# Una visita = una ráfaga de 1-4 fotos separadas 5-60 s
burst <- function(t0, species) {
  n <- sample(1:4, 1L)
  data.frame(
    true_time     = t0 + cumsum(c(0, runif(n - 1L, 5, 60))),
    species       = species,
    n_individuals = sample(1:3, 1L, prob = c(.6, .3, .1)),
    det_conf      = round(runif(n, 0.6, 0.98), 2),
    stringsAsFactors = FALSE
  )
}

simulate_camera <- function(cam) {
  dep   <- deployments[deployments$camera_id == cam, ]
  start <- as.POSIXct(dep$deploy_start, tz = tz)
  end   <- as.POSIXct(dep$deploy_end, tz = tz)
  rows  <- list()
  for (sp in names(visits[[cam]])) {
    n_vis <- rpois(1L, visits[[cam]][[sp]])
    for (v in seq_len(n_vis)) {
      t0 <- draw_time(active_hours[[sp]], start, end)
      rows[[length(rows) + 1L]] <- burst(t0, sp)
      if (runif(1L) < 0.35) {  # revisita a 35-55 min
        rows[[length(rows) + 1L]] <- burst(t0 + runif(1L, 35, 55) * 60, sp)
      }
    }
  }
  # Disparos en falso (vegetación, sol) y detecciones dudosas
  n_false <- sample(6:10, 1L)
  rows[[length(rows) + 1L]] <- data.frame(
    true_time = start + runif(n_false, 0, as.numeric(end - start, units = "secs")),
    species = NA_character_, n_individuals = 0L,
    det_conf = round(runif(n_false, 0.02, 0.35), 2), stringsAsFactors = FALSE)
  n_doubt <- sample(2:4, 1L)
  rows[[length(rows) + 1L]] <- data.frame(
    true_time = start + runif(n_doubt, 0, as.numeric(end - start, units = "secs")),
    species = sample(names(visits[[cam]]), n_doubt, replace = TRUE),
    n_individuals = 1L,
    det_conf = round(runif(n_doubt, 0.30, 0.49), 2), stringsAsFactors = FALSE)

  d <- do.call(rbind, rows)
  d <- d[d$true_time < end, ]
  d <- d[order(d$true_time), ]
  d$file <- sprintf("IMG_%04d.JPG", seq_len(nrow(d)))

  # El reloj de la cámara: CT03 se reinicia tras el cambio de pilas
  cam_time <- d$true_time
  if (cam == "CT03") {
    after <- d$true_time >= battery_change
    cam_time[after] <- clock_reset_to + (d$true_time[after] - battery_change)
  }
  d$datetime_exif <- format(cam_time, "%Y:%m:%d %H:%M:%S", tz = tz)
  d[, c("file", "datetime_exif", "species", "n_individuals", "det_conf")]
}

write_safely <- function(df, path) {
  if (file.exists(path) && !overwrite) {
    stop("Ya existe ", path, ". Pon overwrite <- TRUE si de verdad quieres regenerarlo.")
  }
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(df, path, row.names = FALSE, na = "")
  message("Escrito: ", path, " (", nrow(df), " filas)")
}

for (cam in deployments$camera_id) {
  write_safely(simulate_camera(cam),
               file.path(out_root, "data_raw", cam, "etiquetas.csv"))
}
write_safely(deployments, file.path(out_root, "data", "despliegues.csv"))

sessionInfo()
