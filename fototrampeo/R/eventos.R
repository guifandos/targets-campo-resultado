# fototrampeo/R/eventos.R
# -------------------------------------------------------------------
# De fotos a eventos independientes. Una ráfaga de 4 fotos del mismo
# jabalí no son 4 detecciones. Se agrupan las fotos de una especie en
# una cámara mientras el tiempo entre fotos no supere el umbral.
# El umbral (30 min es una convención muy usada) es una DECISIÓN del
# análisis, no una propiedad biológica: cámbialo y mira qué cambia.
# -------------------------------------------------------------------

#' Eventos independientes de UNA tarjeta
#'
#' @param tags_qc       salida de qc_clock() para una tarjeta
#' @param threshold_min minutos sin fotos de la especie para abrir evento nuevo
#' @return data.frame: camera_id, species, event_start, event_end,
#'         n_photos, max_individuals; o NULL si no hay fotos válidas
independent_events <- function(tags_qc, threshold_min) {
  d <- tags_qc[tags_qc$qc_pass, ]
  if (nrow(d) == 0L) return(NULL)
  d <- d[order(d$species, d$datetime), ]
  gap_min  <- c(Inf, as.numeric(diff(d$datetime), units = "mins"))
  new_sp   <- c(TRUE, d$species[-1] != d$species[-nrow(d)])
  d$event  <- cumsum(new_sp | gap_min > threshold_min)
  ev <- lapply(split(d, d$event), function(e) {
    data.frame(camera_id       = e$camera_id[1],
               species         = e$species[1],
               event_start     = min(e$datetime),
               event_end       = max(e$datetime),
               n_photos        = nrow(e),
               max_individuals = max(e$n_individuals),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, ev)
  rownames(out) <- NULL
  out
}
