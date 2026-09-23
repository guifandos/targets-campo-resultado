# tools/generar_sd_nueva.R
# -------------------------------------------------------------------
# Genera los WAV sintéticos de 'nueva_descarga/' (la "SD que llega tarde"
# del ejercicio de ramas). NO forma parte del pipeline: se ejecuta una vez
# para crear los datos de ejemplo y queda aquí para que sean reproducibles.
#
#   Rscript tools/generar_sd_nueva.R
#
# Mismo formato que los WAV de data_raw/: 8 kHz, mono, 16 bit, 10 s, con un
# campo Comment (chunk LIST/INFO/ICMT) al estilo AudioMoth, para que
# parse_metadata() pueda validar nombre vs cabecera.
# -------------------------------------------------------------------

set.seed(2026)

out_dir   <- file.path("nueva_descarga", "AM01")
times     <- c("064000", "065000")   # 06:40 y 06:50 del 1 de mayo de 2026
date_str  <- "20260501"
sr        <- 8000L
dur_s     <- 10
overwrite <- FALSE

# Señal: ruido de fondo + unos cuantos barridos de frecuencia tipo canto.
synth_signal <- function(sr, dur_s) {
  n <- sr * dur_s
  t <- seq(0, dur_s, length.out = n + 1L)[-1L]
  x <- rnorm(n, sd = 0.02)
  for (k in seq_len(sample(3:6, 1L))) {
    t0  <- runif(1L, 0, dur_s - 0.5)
    len <- runif(1L, 0.15, 0.4)
    f0  <- runif(1L, 1800, 2600)
    f1  <- f0 + runif(1L, 400, 1200)
    idx <- which(t >= t0 & t < t0 + len)
    tt  <- t[idx] - t0
    phase <- 2 * pi * (f0 * tt + (f1 - f0) * tt^2 / (2 * len))
    env   <- sin(pi * tt / len)^2
    x[idx] <- x[idx] + 0.5 * env * sin(phase)
  }
  pmax(pmin(x, 1), -1)
}

# Escribir un WAV PCM 16 bit mono con chunk LIST/INFO/ICMT, en R base.
write_wav_with_comment <- function(path, x, sr, comment) {
  samples <- as.integer(round(x * 32767))
  data_raw <- writeBin(samples, raw(), size = 2L, endian = "little")

  le32 <- function(v) writeBin(as.integer(v), raw(), size = 4L, endian = "little")
  le16 <- function(v) writeBin(as.integer(v), raw(), size = 2L, endian = "little")
  tag  <- function(s) charToRaw(s)

  fmt <- c(tag("fmt "), le32(16L), le16(1L), le16(1L), le32(sr),
           le32(sr * 2L), le16(2L), le16(16L))
  dat <- c(tag("data"), le32(length(data_raw)), data_raw)

  txt <- c(charToRaw(comment), as.raw(0L))
  if (length(txt) %% 2L == 1L) txt <- c(txt, as.raw(0L))
  info <- c(tag("INFO"), tag("ICMT"), le32(length(txt)), txt)
  lst  <- c(tag("LIST"), le32(length(info)), info)

  body <- c(tag("WAVE"), fmt, dat, lst)
  writeBin(c(tag("RIFF"), le32(length(body)), body), path)
}

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
for (hms in times) {
  path <- file.path(out_dir, sprintf("%s_%s.WAV", date_str, hms))
  if (file.exists(path) && !overwrite) {
    stop("Ya existe ", path, ". Pon overwrite <- TRUE si de verdad quieres regenerarlo.")
  }
  hhmmss  <- paste(substring(hms, c(1, 3, 5), c(2, 4, 6)), collapse = ":")
  comment <- sprintf("Recorded at %s 01/05/2026 (UTC) by AudioMoth 24F3190A at medium gain (demo).",
                     hhmmss)
  write_wav_with_comment(path, synth_signal(sr, dur_s), sr, comment)
  message("Escrito: ", path)
}

sessionInfo()
