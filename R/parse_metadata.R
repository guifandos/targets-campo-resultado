# R/parse_metadata.R
# -------------------------------------------------------------------
# Etapa 2 del flujo: extraer metadatos de las grabaciones.
#
# Regla de oro (mensaje para la charla): NO te fíes solo del nombre del
# archivo. Extrae la fecha/hora de DOS fuentes y valida que coinciden:
#   (a) el nombre del archivo  -> rápido, pero el usuario puede renombrar
#   (b) la metadata interna    -> AudioMoth la mete en el campo "Comment"
# Si (a) y (b) discrepan, hay un problema (zona horaria, renombrado, etc.).
# -------------------------------------------------------------------

#' Listar archivos de audio de una carpeta
#' @param dir carpeta a escanear (recursivo)
#' @return vector de rutas .wav/.WAV
list_audio <- function(dir) {
  files <- list.files(dir, pattern = "\\.wav$", ignore.case = TRUE,
                       full.names = TRUE, recursive = TRUE)
  if (length(files) == 0L) {
    warning("No se encontraron .wav en: ", dir)
  }
  files
}

#' Parsear fecha/hora desde el NOMBRE del archivo
#'
#' Soporta los dos formatos habituales de campo:
#'   - AudioMoth firmware nuevo y Song Meter: "YYYYMMDD_HHMMSS"
#'   - AudioMoth firmware viejo: hexadecimal (p. ej. "5E90A4D4.WAV")
#'
#' @param path ruta o nombre del archivo
#' @param tz   zona horaria con la que el grabador nombró el archivo
#' @return POSIXct (UTC-naive ajustado a tz) o NA si no reconoce el patrón
datetime_from_name <- function(path, tz = "UTC") {
  fn <- basename(path)

  # Patrón 1: YYYYMMDD_HHMMSS (lo más común hoy)
  m <- regmatches(fn, regexpr("[0-9]{8}_[0-9]{6}", fn))
  if (length(m) == 1L && nzchar(m)) {
    return(as.POSIXct(m, format = "%Y%m%d_%H%M%S", tz = tz))
  }

  # Patrón 2: hexadecimal AudioMoth antiguo (segundos UNIX en hex)
  hex <- toupper(sub("\\.wav$", "", fn, ignore.case = TRUE))
  if (grepl("^[0-9A-F]{8}$", hex)) {
    secs <- strtoi(hex, base = 16L)
    return(as.POSIXct(secs, origin = "1970-01-01", tz = "UTC"))
  }

  warning("Patrón de nombre no reconocido: ", fn)
  as.POSIXct(NA)
}

#' Leer el campo Comment (chunk ICMT) de un WAV con R base, SIN dependencias
#'
#' AudioMoth escribe en el bloque LIST/INFO del WAV un campo Comment del tipo
#' "Recorded at HH:MM:SS DD/MM/YYYY (UTC) by AudioMoth ...". Esta función
#' escanea los bytes en busca de la firma "ICMT" y devuelve ese texto. Es el
#' plan B cuando 'sonicscrewdriver' no está instalado (p. ej. en la demo).
#'
#' @param path ruta del archivo
#' @return el comentario (string) o NULL si no hay
read_wav_comment <- function(path) {
  sz <- file.info(path)$size
  if (is.na(sz) || sz < 12L) return(NULL)
  raw <- readBin(path, what = "raw", n = sz)
  pos <- grepRaw("ICMT", raw, fixed = TRUE)          # offset de la firma (1-based)
  if (length(pos) == 0L || (pos + 7L) > length(raw)) return(NULL)
  len <- readBin(raw[(pos + 4L):(pos + 7L)], "integer", n = 1L, size = 4L, endian = "little")
  if (is.na(len) || len <= 0L || (pos + 7L + len) > length(raw)) return(NULL)
  bytes <- raw[(pos + 8L):(pos + 7L + len)]
  bytes <- bytes[bytes != as.raw(0L)]                # quitar el/los null terminadores
  trimws(rawToChar(bytes))
}

#' Extraer la fecha/hora (UTC) del texto Comment de AudioMoth
#'
#' @param comment texto del campo Comment
#' @return POSIXct en UTC, o NA si no encuentra el patrón
datetime_from_comment <- function(comment) {
  if (is.null(comment)) return(as.POSIXct(NA))
  m <- regmatches(comment, regexpr("[0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{2}/[0-9]{2}/[0-9]{4}", comment))
  if (length(m) != 1L || !nzchar(m)) return(as.POSIXct(NA))
  as.POSIXct(m, format = "%H:%M:%S %d/%m/%Y", tz = "UTC")
}

#' Leer metadata INTERNA de un WAV de AudioMoth (campo Comment)
#'
#' Orden de preferencia:
#'   1) sonicscrewdriver::audiomoth_wave() si está instalado (opción nativa).
#'   2) Plan B sin dependencias: leer el chunk ICMT con read_wav_comment().
#' Para Song Meter (SM4) la info equivalente suele ir en ficheros aparte,
#' no en la cabecera del WAV: ahí te quedas con el nombre + el log del SM4.
#'
#' @param path ruta del archivo
#' @return lista con (al menos) $datetime, o lista vacía si no se puede leer
metadata_from_wave <- function(path) {
  if (requireNamespace("sonicscrewdriver", quietly = TRUE)) {
    out <- tryCatch(
      sonicscrewdriver::audiomoth_wave(path),
      error = function(e) {
        warning("No se pudo leer metadata interna de: ", basename(path),
                " (", conditionMessage(e), ")")
        list()
      }
    )
    if (length(out)) return(out)
  }
  # Plan B (demo): leer el campo Comment con R base.
  comment <- read_wav_comment(path)
  if (is.null(comment) || !nzchar(comment)) {
    warning("Sin metadata interna legible en ", basename(path),
            " (instala 'sonicscrewdriver' o usa WAV con campo Comment).")
    return(list())
  }
  list(datetime = datetime_from_comment(comment), comment = comment)
}

#' Construir una fila de metadatos por archivo, validando nombre vs cabecera
#'
#' @param path        ruta del archivo
#' @param tz          zona horaria del nombre
#' @param read_header TRUE para leer también la cabecera interna (más lento)
#' @param tol_secs    tolerancia (s) permitida entre ambas fuentes
#' @return data.frame de 1 fila
parse_one <- function(path, tz = "UTC", read_header = TRUE, tol_secs = 2) {
  dt_name <- datetime_from_name(path, tz = tz)

  # recorder_id: AudioMoth NO lo guarda en el nombre (Song Meter sí). Lo
  # tomamos de la carpeta padre -> por eso conviene una carpeta por grabador.
  # (data_raw/AM01/...wav  ->  recorder_id = "AM01")
  recorder_id <- basename(dirname(path))

  # Duración real leyendo solo la cabecera del WAV (rápido, no carga la señal)
  hdr <- tryCatch(tuneR::readWave(path, header = TRUE),
                  error = function(e) NULL)
  dur_s   <- if (!is.null(hdr)) hdr$samples / hdr$sample.rate else NA_real_
  srate   <- if (!is.null(hdr)) hdr$sample.rate else NA_real_

  dt_hdr <- as.POSIXct(NA)
  if (read_header) {
    meta <- metadata_from_wave(path)
    if (!is.null(meta$datetime)) dt_hdr <- as.POSIXct(meta$datetime)
  }

  # Validación cruzada: ¿coincide el nombre con la cabecera?
  mismatch <- NA
  if (!is.na(dt_name) && !is.na(dt_hdr)) {
    mismatch <- abs(as.numeric(difftime(dt_name, dt_hdr, units = "secs"))) > tol_secs
    if (isTRUE(mismatch)) {
      warning("DISCREPANCIA nombre vs cabecera en ", basename(path),
              " (revisa zona horaria o renombrado).")
    }
  }

  data.frame(
    file        = path,
    filename    = basename(path),
    recorder_id = recorder_id,
    datetime    = if (!is.na(dt_name)) dt_name else dt_hdr,
    dt_name     = dt_name,
    dt_header   = dt_hdr,
    name_vs_header_mismatch = mismatch,
    duration_s  = dur_s,
    sample_rate = srate,
    stringsAsFactors = FALSE
  )
}

#' Parsear una carpeta entera -> data.frame de metadatos
#' @param files vector de rutas (de list_audio)
#' @param ...   argumentos pasados a parse_one()
parse_metadata <- function(files, ...) {
  do.call(rbind, lapply(files, parse_one, ...))
}
