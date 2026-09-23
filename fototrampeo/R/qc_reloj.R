# fototrampeo/R/qc_reloj.R
# -------------------------------------------------------------------
# QC antes de contar nada. El fallo más caro en fototrampeo es el reloj:
# tras cambiar las pilas, muchas cámaras vuelven a una fecha de fábrica
# (p. ej. 2000-01-01) y las fotos caen fuera del despliegue. R no da
# ningún error: solo lo ves si comparas con las fechas de campo.
# -------------------------------------------------------------------

#' Marcar fotos problemáticas de UNA tarjeta
#'
#' @param tags        salida de parse_tags() para una tarjeta
#' @param deployments salida de read_deployments()
#' @param min_conf    confianza mínima del detector; calíbrala con una
#'                    muestra de fotos revisadas a mano
#' @return tags con columnas qc_* añadidas
qc_clock <- function(tags, deployments, min_conf) {
  cam <- unique(tags$camera_id)
  dep <- deployments[deployments$camera_id == cam, ]
  if (nrow(dep) != 1L) {
    stop("La cámara ", cam, " no tiene exactamente una fila en despliegues.csv.")
  }
  tags$qc_out_of_window <- is.na(tags$datetime) |
    tags$datetime < dep$deploy_start | tags$datetime > dep$deploy_end
  tags$qc_empty    <- is.na(tags$species)
  tags$qc_low_conf <- tags$det_conf < min_conf
  tags$qc_pass <- !(tags$qc_out_of_window | tags$qc_empty | tags$qc_low_conf)
  tags
}

#' Resumen de QC por cámara (se imprime y se guarda como tabla)
clock_summary <- function(tags_qc) {
  s <- do.call(rbind, lapply(split(tags_qc, tags_qc$camera_id), function(d) {
    data.frame(camera_id     = d$camera_id[1],
               fotos         = nrow(d),
               fuera_despl   = sum(d$qc_out_of_window),
               vacias        = sum(d$qc_empty),
               conf_baja     = sum(d$qc_low_conf & !d$qc_empty),
               pasan_qc      = sum(d$qc_pass))
  }))
  rownames(s) <- NULL
  print(s)
  if (any(s$fuera_despl > 0L)) {
    cat("AVISO: fotos fuera del despliegue en",
        paste(s$camera_id[s$fuera_despl > 0L], collapse = ", "),
        "-> revisa el reloj de la cámara.\n")
  }
  s
}
