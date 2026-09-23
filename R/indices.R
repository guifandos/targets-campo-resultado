# R/indices.R
# -------------------------------------------------------------------
# Etapa 4 del flujo: procesado/detección.
# Dos caminos no excluyentes:
#   A) Índices acústicos (resumen del paisaje sonoro)  -> soundecology / seewave
#   B) Clasificación de especies                       -> BirdNET / Perch (Python)
#
# Mensaje para la charla: R aquí es ORQUESTADOR. BirdNET no es R; se lanza
# como proceso externo y se recoge la salida. Sin peleas R-vs-Python.
# -------------------------------------------------------------------

#' Índices "básicos" SIN dependencias extra (solo tuneR/seewave)
#'
#' Pensado para que el pipeline corra de fábrica en la demo. Calcula RMS
#' (energía) y entropía espectral de Shannon (proxy de "complejidad" del
#' paisaje sonoro). En datos reales, sustituye por compute_indices() o
#' por scikit-maad.
#'
#' @param files vector de rutas (idealmente filtradas por qc_pass)
#' @return data.frame: file + rms + spectral_entropy
compute_indices_basic <- function(files) {
  rows <- lapply(files, function(f) {
    w <- tuneR::readWave(f)
    x <- w@left / 2^(w@bit - 1)          # normaliza a [-1, 1]
    rms <- sqrt(mean(x^2))
    sh  <- tryCatch(seewave::sh(seewave::spec(w, plot = FALSE)),
                    error = function(e) NA_real_)  # entropía espectral
    data.frame(file = f, rms = rms, spectral_entropy = sh)
  })
  do.call(rbind, rows)
}

#' Calcular índices de UN archivo solo si pasa QC (pensado para ramas)
#'
#' Con dynamic branching cada rama recibe un archivo y su fila de QC. Si el
#' archivo no pasa QC devuelve NULL: al agregar las ramas, targets descarta
#' los NULL, así que la tabla de índices solo contiene archivos válidos.
#' Como la rama depende del VALOR de su fila de QC, cambiar un umbral solo
#' recalcula las ramas cuyo resultado de QC cambia.
#'
#' @param file ruta de un archivo (una rama de audio_files)
#' @param qc   fila de QC de ese mismo archivo (una rama de meta_qc)
#' @param fun  función de índices: compute_indices_basic o compute_indices
#' @return data.frame de 1 fila, o NULL si el archivo no pasa QC
indices_if_pass <- function(file, qc, fun = compute_indices_basic) {
  if (nrow(qc) != 1L || !identical(qc$file, file)) {
    stop("La rama de QC no corresponde al archivo ", basename(file),
         ": revisa que audio_files y meta_qc se mapeen en el mismo orden.")
  }
  if (!isTRUE(qc$qc_pass)) return(NULL)
  fun(file)
}

#' Índices acústicos por archivo con soundecology
#'
#' Calcula ACI, ADI, AEI, bioacoustic index, NDSI... (según funciones de
#' soundecology) sobre archivos que pasan QC.
#'
#' @param files vector de rutas (idealmente ya filtradas por qc_pass)
#' @return data.frame: file + un índice por columna
compute_indices <- function(files) {
  if (!requireNamespace("soundecology", quietly = TRUE)) {
    stop("Instala 'soundecology' (o usa scikit-maad en Python para más índices).")
  }
  rows <- lapply(files, function(f) {
    w <- tuneR::readWave(f)
    aci  <- tryCatch(soundecology::acoustic_complexity(w)$AciTotAll_left, error = function(e) NA_real_)
    ndsi <- tryCatch(soundecology::ndsi(w)$ndsi_left,                    error = function(e) NA_real_)
    adi  <- tryCatch(soundecology::acoustic_diversity(w)$adi_left,       error = function(e) NA_real_)
    data.frame(file = f, aci = aci, ndsi = ndsi, adi = adi)
  })
  do.call(rbind, rows)
}

#' Lanzar BirdNET-Analyzer sobre una carpeta, DESDE R
#'
#' Opción 1 (recomendada para producción): usar el paquete NSNSDAcoustics,
#'   que envuelve BirdNET y devuelve tablas listas (ver docs/recursos.md).
#' Opción 2 (mostrada aquí): llamada directa al CLI con processx/system2.
#'   Útil en la charla para enseñar que R solo coordina.
#'
#' @param audio_dir  carpeta con los .wav
#' @param out_dir    carpeta de salida para los CSV de BirdNET
#' @param min_conf   confianza mínima
#' @param threads    núcleos
#' @return rutas de los CSV generados
run_birdnet <- function(audio_dir, out_dir, min_conf = 0.25, threads = 4) {
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  # Ajusta el comando a tu instalación de BirdNET-Analyzer:
  args <- c("-m", "birdnet_analyzer.analyze",
            "--i", audio_dir,
            "--o", out_dir,
            "--min_conf", format(min_conf),
            "--threads", as.character(threads),
            "--rtype", "csv")
  if (requireNamespace("processx", quietly = TRUE)) {
    processx::run("python", args, echo = TRUE)
  } else {
    system2("python", args)  # alternativa de base R
  }
  list.files(out_dir, pattern = "\\.csv$", full.names = TRUE)
}

#' Leer y apilar los CSV de salida de BirdNET en un data.frame
read_birdnet_out <- function(csv_files) {
  if (length(csv_files) == 0L) return(data.frame())
  do.call(rbind, lapply(csv_files, function(f) {
    d <- utils::read.csv(f, stringsAsFactors = FALSE)
    d$source_file <- basename(f)
    d
  }))
}
