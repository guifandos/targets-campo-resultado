# fototrampeo/R/esfuerzo.R
# -------------------------------------------------------------------
# Esfuerzo de muestreo (cámara-día) y tasa de detección.
# Si el reloj se reinicia, no sabemos cuándo dejó de ser fiable la
# cámara: el esfuerzo se corta en la última foto válida ANTES de la
# primera foto fuera del despliegue (estimación conservadora), para que
# esfuerzo y eventos cubran el mismo periodo.
# -------------------------------------------------------------------

#' Esfuerzo efectivo de UNA cámara
#'
#' @param tags_qc     salida de qc_clock() para una tarjeta
#' @param deployments salida de read_deployments()
#' @return data.frame de 1 fila: camera_id, effort_start, effort_end,
#'         effort_days, effort_note
camera_effort <- function(tags_qc, deployments) {
  cam <- unique(tags_qc$camera_id)
  dep <- deployments[deployments$camera_id == cam, ]
  end  <- dep$deploy_end
  note <- "despliegue completo"
  first_bad <- which(tags_qc$qc_out_of_window)[1]   # tags_qc va en orden de archivo
  if (!is.na(first_bad)) {
    ok_before <- which(!tags_qc$qc_out_of_window[seq_len(first_bad - 1L)])
    end <- if (length(ok_before) > 0L) {
      tags_qc$datetime[max(ok_before)]
    } else {
      dep$deploy_start
    }
    note <- sprintf("reloj no fiable desde %s: esfuerzo hasta la última foto válida",
                    tags_qc$file[first_bad])
  }
  data.frame(camera_id    = cam,
             effort_start = dep$deploy_start,
             effort_end   = end,
             effort_days  = round(as.numeric(difftime(end, dep$deploy_start,
                                                      units = "days")), 2),
             effort_note  = note,
             stringsAsFactors = FALSE)
}

#' Tasa de detección: eventos independientes por 100 cámara-día
#'
#' NO es abundancia: depende de la detectabilidad de cada especie, de su
#' área de campeo y de la colocación de la cámara (Sollmann et al. 2013,
#' Biol. Conserv.). Incluye los CEROS: especie no detectada en una cámara.
#'
#' @param events      eventos (todas las ramas combinadas)
#' @param effort      esfuerzo (todas las ramas combinadas)
#' @param deployments diseño de muestreo
#' @return data.frame: una fila por cámara y especie
detection_rates <- function(events, effort, deployments) {
  if (is.null(events) || nrow(events) == 0L) {
    stop("No hay eventos: ninguna foto pasó el QC.")
  }
  assert_unique_key(effort, "camera_id")   # de R/consolidate.R
  grid <- expand.grid(camera_id = effort$camera_id,
                      species   = sort(unique(events$species)),
                      stringsAsFactors = FALSE)
  counts <- dplyr::count(events, camera_id, species, name = "n_events")
  out <- grid |>
    dplyr::left_join(counts, by = c("camera_id", "species")) |>
    dplyr::left_join(effort, by = "camera_id") |>
    dplyr::left_join(deployments[, c("camera_id", "site", "lat", "lon", "habitat")],
                     by = "camera_id")
  if (nrow(out) != nrow(grid)) {
    warning(sprintf("El join cambió el nº de filas (%d -> %d).", nrow(grid), nrow(out)))
  }
  out$n_events[is.na(out$n_events)] <- 0L
  out$rate_100 <- ifelse(out$effort_days > 0,
                         round(100 * out$n_events / out$effort_days, 1), NA_real_)
  out[order(out$camera_id, out$species), ]
}
