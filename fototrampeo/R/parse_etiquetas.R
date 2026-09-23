# fototrampeo/R/parse_etiquetas.R
# -------------------------------------------------------------------
# Ingesta: una tabla de etiquetas por tarjeta SD (una fila por foto),
# tal como sale del detector y del etiquetado. La cámara se identifica
# por la CARPETA, igual que el grabador en el caso acústico:
#   fototrampeo/data_raw/CT01/etiquetas.csv  ->  camera_id = CT01
# -------------------------------------------------------------------

#' Listar las tablas de etiquetas (una por tarjeta)
list_tag_files <- function(dir) {
  files <- list.files(dir, pattern = "^etiquetas\\.csv$",
                      full.names = TRUE, recursive = TRUE)
  if (length(files) == 0L) {
    warning("No se encontraron etiquetas.csv en: ", dir)
  }
  files
}

#' Leer una tabla de etiquetas y parsear la fecha EXIF
#'
#' EXIF escribe la fecha con dos puntos ("2026:05:03 21:14:07"): el
#' formato por defecto de as.POSIXct() no la entiende, hay que darlo.
#'
#' @param path ruta de etiquetas.csv
#' @param tz   zona horaria con la que se configuró la cámara
#' @return data.frame: camera_id, file, datetime, species, n_individuals, det_conf
parse_tags <- function(path, tz) {
  d <- utils::read.csv(path, stringsAsFactors = FALSE,
                       na.strings = c("", "NA"),
                       colClasses = c(datetime_exif = "character"))
  d$datetime <- as.POSIXct(d$datetime_exif, format = "%Y:%m:%d %H:%M:%S", tz = tz)
  n_bad <- sum(is.na(d$datetime))
  if (n_bad > 0L) {
    warning(n_bad, " fechas EXIF sin parsear en ", path)
  }
  d$camera_id <- basename(dirname(path))
  d[order(d$file), c("camera_id", "file", "datetime", "species",
                     "n_individuals", "det_conf")]
}

#' Leer el diseño de muestreo: una fila por cámara y despliegue
read_deployments <- function(path, tz) {
  dep <- utils::read.csv(path, stringsAsFactors = FALSE)
  assert_unique_key(dep, "camera_id")   # de R/consolidate.R
  dep$deploy_start <- as.POSIXct(dep$deploy_start, tz = tz)
  dep$deploy_end   <- as.POSIXct(dep$deploy_end, tz = tz)
  dep
}
