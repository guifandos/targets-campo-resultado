# ============================================================
# check_setup.R — comprueba tu equipo ANTES del taller
#
# Abre el proyecto (targets-campo-resultado.Rproj) en RStudio y ejecuta:
#   source("check_setup.R")
#
# No instala nada ni modifica el proyecto: si falta algo, te dice qué
# ejecutar. El pipeline se prueba en una copia temporal.
# ============================================================

check_setup <- function() {
  problems <- character(0)
  ok   <- function(...) cat("  [OK]    ", ..., "\n", sep = "")
  fail <- function(...) {
    cat("  [FALLO] ", ..., "\n", sep = "")
    problems <<- c(problems, paste0(...))
  }

  cat("\n1. Versión de R\n")
  if (getRversion() >= "4.2.0") ok(R.version.string)
  else fail(R.version.string, " -> instala R >= 4.2 desde https://cran.r-project.org")

  cat("\n2. Paquetes\n")
  required <- c("targets", "tarchetypes", "tuneR", "seewave", "dplyr")
  missing  <- required[!vapply(required, requireNamespace, logical(1),
                               quietly = TRUE)]
  for (p in setdiff(required, missing)) ok(p, " ", format(utils::packageVersion(p)))
  if (length(missing) > 0L) {
    fail("faltan paquetes. Ejecuta en la consola:\n          install.packages(c(",
         paste0('"', missing, '"', collapse = ", "), "))")
  }
  if (requireNamespace("visNetwork", quietly = TRUE)) {
    ok("visNetwork (opcional, para tar_visnetwork())")
  } else {
    cat("  [--]    visNetwork no instalado (opcional, para tar_visnetwork())\n")
  }

  cat("\n3. Directorio de trabajo\n")
  wd <- getwd()
  if (file.exists("_targets.R") && dir.exists("data_raw")) {
    ok(wd)
  } else {
    fail("no estás en la carpeta del proyecto (", wd, ").\n",
         "          Abre targets-campo-resultado.Rproj o usa Session > Set Working Directory.")
  }
  if (grepl("onedrive", wd, ignore.case = TRUE)) {
    fail("el proyecto está dentro de OneDrive; la sincronización puede romper",
         " la caché de targets. Muévelo fuera (p. ej. C:/Users/<tu_usuario>/).")
  }

  cat("\n4. Ejecución de los pipelines (en una copia temporal)\n")
  if (length(missing) == 0L && file.exists("_targets.R")) {
    tmp <- file.path(tempdir(), "check_targets")
    unlink(tmp, recursive = TRUE)
    dir.create(tmp)
    files <- c("_targets.R", "_targets.yaml", "R", "data", "data_raw",
               "output", "fototrampeo")
    file.copy(files[file.exists(files)], tmp, recursive = TRUE)
    # Empezar sin cachés ni salidas previas
    unlink(file.path(tmp, c("_targets", "fototrampeo/_targets")), recursive = TRUE)
    unlink(file.path(tmp, c("output/tabla_analisis.csv",
                            "fototrampeo/output/tasas_deteccion.csv")))
    old <- setwd(tmp)
    on.exit({ setwd(old); Sys.unsetenv("TAR_PROJECT") }, add = TRUE)

    # Ejecuta un proyecto de targets y devuelve el nº de filas de su tabla
    run_project <- function(project, csv) {
      tryCatch({
        Sys.setenv(TAR_PROJECT = project)
        targets::tar_make(reporter = "silent")
        nrow(utils::read.csv(csv))
      }, error = function(e) conditionMessage(e),
      finally = Sys.unsetenv("TAR_PROJECT"))
    }
    res_ac <- run_project("main", "output/tabla_analisis.csv")
    res_ct <- if (file.exists("_targets.yaml")) {
      run_project("fototrampeo", "fototrampeo/output/tasas_deteccion.csv")
    } else {
      "falta _targets.yaml"
    }
    setwd(old)
    unlink(tmp, recursive = TRUE)
    if (identical(res_ac, 5L)) ok("ecoacústica: tar_make() genera la tabla con 5 filas")
    else fail("ecoacústica: tar_make() no dio el resultado esperado: ", res_ac)
    if (identical(res_ct, 12L)) ok("fototrampeo: tar_make() genera la tabla con 12 filas")
    else fail("fototrampeo: tar_make() no dio el resultado esperado: ", res_ct)
  } else {
    cat("  [--]    se omite hasta resolver los puntos anteriores\n")
  }

  cat("\n")
  if (length(problems) == 0L) {
    cat("TODO LISTO. Nos vemos en el taller.\n\n")
  } else {
    cat("Hay ", length(problems), " problema(s). Resuélvelos o escríbeme antes",
        " del taller; en la sesión no habrá tiempo para instalar.\n\n", sep = "")
  }
  invisible(length(problems) == 0L)
}

check_setup()
