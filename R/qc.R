# R/qc.R
# -------------------------------------------------------------------
# Etapa 3 del flujo: control de calidad ANTES de analizar.
# Lo que casi todo el mundo se salta y luego cuesta caro.
# -------------------------------------------------------------------

#' Marcar archivos problemáticos a partir de la tabla de metadatos
#'
#' Comprueba: archivos sin fecha, duración anómala (truncados o más largos
#' de lo esperado), y discrepancias nombre/cabecera ya detectadas.
#'
#' @param meta data.frame de parse_metadata()
#' @param expected_dur_s duración nominal esperada por archivo (s); NULL = no chequear
#' @param tol_frac tolerancia relativa sobre la duración esperada
#' @return el data.frame con columnas qc_* añadidas
qc_flag <- function(meta, expected_dur_s = NULL, tol_frac = 0.05) {
  meta$qc_no_datetime <- is.na(meta$datetime)
  meta$qc_zero_len    <- !is.na(meta$duration_s) & meta$duration_s <= 0
  meta$qc_mismatch    <- isTRUE_vec(meta$name_vs_header_mismatch)

  if (!is.null(expected_dur_s)) {
    lo <- expected_dur_s * (1 - tol_frac)
    hi <- expected_dur_s * (1 + tol_frac)
    meta$qc_bad_duration <- !is.na(meta$duration_s) &
      (meta$duration_s < lo | meta$duration_s > hi)
  } else {
    meta$qc_bad_duration <- FALSE
  }

  meta$qc_pass <- !(meta$qc_no_datetime | meta$qc_zero_len |
                      meta$qc_bad_duration)
  meta
}

# Helper: TRUE solo donde el valor es TRUE (NA -> FALSE)
isTRUE_vec <- function(x) !is.na(x) & x

#' Detectar huecos en el calendario de grabación
#'
#' Útil para ver si un grabador se quedó sin batería/SD a mitad de campaña.
#' Se calcula POR GRABADOR: si se mezclan las fechas de todos, las
#' grabaciones de un aparato tapan los huecos del otro.
#'
#' @param meta data.frame con columnas recorder_id y datetime
#' @param expected_interval_min intervalo nominal entre grabaciones (min)
#' @return data.frame de huecos detectados (grabador, inicio, fin, horas)
qc_schedule_gaps <- function(meta, expected_interval_min) {
  one_recorder <- function(id) {
    dt <- sort(meta$datetime[meta$recorder_id == id & !is.na(meta$datetime)])
    if (length(dt) < 2L) return(NULL)
    diffs <- as.numeric(diff(dt), units = "mins")
    gap_idx <- which(diffs > expected_interval_min * 1.5)
    if (length(gap_idx) == 0L) return(NULL)
    data.frame(
      recorder_id  = id,
      gap_start    = dt[gap_idx],
      gap_end      = dt[gap_idx + 1L],
      gap_hours    = round(diffs[gap_idx] / 60, 2)
    )
  }
  out <- do.call(rbind, lapply(sort(unique(meta$recorder_id)), one_recorder))
  if (is.null(out)) data.frame() else out
}

#' Resumen rápido de QC para imprimir en consola / log
qc_summary <- function(meta) {
  n <- nrow(meta)
  cat("Archivos:                ", n, "\n")
  cat("  Sin fecha:             ", sum(meta$qc_no_datetime), "\n")
  cat("  Longitud cero/corrupto:", sum(meta$qc_zero_len), "\n")
  cat("  Duración anómala:      ", sum(meta$qc_bad_duration), "\n")
  cat("  Discrepancia nombre/hdr:", sum(meta$qc_mismatch), "\n")
  cat("  PASAN QC:              ", sum(meta$qc_pass), "/", n, "\n")
  invisible(meta)
}
