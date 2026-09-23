# Recursos abiertos que ya cubren este flujo

No partimos de cero. Estas herramientas y materiales abiertos resuelven gran
parte del camino de la SD a la tabla.

## Manejo de audio y análisis de señal (R)

- **warbleR** — flujo estandarizado para análisis de estructura de señales
  acústicas en R; se apoya en `seewave` y `tuneR`, permite procesamiento por
  lotes y produce espectrogramas para verificar y organizar datos. Tiene varias
  viñetas con ejemplos de cómo organizar el flujo.
  https://marce10.github.io/warbleR/  (artículo: Araya-Salas & Smith-Vidaurre,
  MEE 2017, doi:10.1111/2041-210X.12624)
- **Rraven** — intercambio de datos entre R y Raven (Cornell); útil para
  importar/exportar tablas de selección.
- **ohun** — detección automática optimizada de señales (alternativa moderna a
  la detección de warbleR).
- **seewave** — incluye `audiomoth()` y `songmeter()` para **decodificar la
  fecha/hora desde el nombre** del archivo (formato hex antiguo y
  `YYYYMMDD_HHMMSS` actual).

## Metadatos de grabadores

- **sonicscrewdriver** — `audiomoth_config()` lee el CONFIG.TXT de la SD;
  `audiomoth_wave()` parsea la metadata embebida en el campo *Comment* del WAV
  (hora, temperatura, batería, ganancia...).
  **Nota:** eliminado de CRAN el 11 de junio de 2026. Disponible como fuente
  desde GitHub (https://github.com/edwbaker/SonicScrewdriveR) hasta nueva
  revisión. La funcionalidad crítica (parseo del campo *Comment*) está
  reimplementada en base R en `R/parse_metadata.R` de este repositorio.
- **GUANO** — estándar abierto para metadata embebida en WAV, ampliamente
  reconocido; conviene conocerlo aunque AudioMoth no lo use por defecto.
- (Python) **metamoth** y **aru_metadata_parser** (Kitzes Lab) — parsean
  metadata de AudioMoth, Song Meter, Swift y OwlSense; útiles si tu pipeline
  cruza a Python.

## Clasificación de especies

- **BirdNET-Analyzer** — modelo de deep learning (MIT + CC BY-NC-SA) para
  detección de >9 000 especies de aves y otros grupos. Interfaz de línea de
  comandos (Python), accesible desde R con `system2()` o via NSNSDAcoustics.
  https://github.com/kahst/BirdNET-Analyzer
- **NSNSDAcoustics** (National Park Service) — paquete R que **envuelve
  BirdNET** desde RStudio: `birdnet_analyzer()` para correr el modelo,
  `birdnet_format()` + `birdnet_verify()` para organizar y verificar miles de
  detecciones, y funciones de visualización (heatmaps temporales con horas
  realmente muestreadas). Soporta salida CSV de BirdNET Analyzer v2.
  https://github.com/nationalparkservice/NSNSDAcoustics
  - Guía de instalación de BirdNET + RStudio (Windows):
    https://cbalantic.github.io/Install-BirdNET-Windows-RStudio/
  - Ejemplo de uso real a gran escala (239k detecciones, 30 sitios, BirdNET vía
    NSNSDAcoustics): dataset urbano de Gotemburgo, *Scientific Data* 2025,
    doi:10.1038/s41597-025-05481-z
- **OpenSoundscape** (Python, MIT, v0.13.0 mayo 2026) — pipeline CNN para
  clasificación acústica; incluye entrenamiento, predicción y evaluación.
  https://github.com/kitzeslab/opensoundscape

## Índices acústicos

- **soundecology** (R) — ACI, ADI, AEI, NDSI, índice bioacústico.
  **Nota:** archivado en CRAN desde 2020; sin mantenimiento activo. Funciona en
  versiones recientes de R pero puede dejar de compilar. Para nuevos proyectos
  considerar scikit-maad (ver abajo).
- **scikit-maad** (Python, BSD-3) — >50 índices espectrales y temporales, false-
  color spectrograms y parseo de fechas desde nombre (`date_parser`). El tutorial
  muestra el modo `SM4` para Song Meter y el formato hex para AudioMoth.
  Accesible desde R con `reticulate`. Artículo: Ulloa et al. (2021, *Methods
  Ecol. Evol.*), doi:10.1111/2041-210X.13711.
  https://scikit-maad.github.io/
- **bacpipe** (Python, Apache-2.0) — compara 23 modelos de embeddings acústicos
  (BirdNET, AVES, Perch/Google, etc.) sobre el mismo corpus. Útil para elegir
  modelo de base antes de clasificar.
  https://github.com/birdclef/bacpipe

## Pipelines de producción

- **SoundADE** (Python, GPL-3) — pipeline HPC modular para procesamiento a gran
  escala (ingesta → índices → detección). Combinado con **echo-dash** para
  visualización interactiva.
  https://github.com/UFSC/SoundADE
- **targets-campo-resultado** (este repositorio) — QC, metadatos, tabla tidy y
  orquestación con `targets` (una rama por archivo), para ecoacústica y
  fototrampeo; diseñado para estudios medianos sin HPC.

## Fototrampeo (segundo caso del taller)

- **MegaDetector** — modelo que detecta animales, personas y vehículos en fotos
  de cámaras trampa (no identifica especies); útil para descartar fotos vacías.
  Paquete de Python. https://github.com/agentmorris/MegaDetector
- **camtrapR** (R) — gestión de datos de fototrampeo: organización de imágenes,
  extracción de metadatos, tablas de registros y preparación de análisis de
  ocupación y captura-recaptura espacial. Niedballa et al. (2016, *Methods Ecol.
  Evol.*), doi:10.1111/2041-210X.12600. https://jniedballa.github.io/camtrapR/
- **Camtrap DP** — estándar abierto para intercambiar y archivar datos de
  fototrampeo (tablas de despliegues, medios y observaciones). Bubnicki et al.
  (2024, *Remote Sens. Ecol. Conserv.*), doi:10.1002/rse2.374.
  https://camtrap-dp.tdwg.org/
- Sollmann et al. (2013, *Biol. Conserv.*): *Risky business or simple solution –
  Relative abundance indices from camera-trapping*. Por qué una tasa de
  detección no es abundancia. doi:10.1016/j.biocon.2012.12.025

## Para seguir con `targets` (lo que no cabe en 45 minutos)

| Necesidad | Herramienta |
|---|---|
| Paralelizar ramas (núcleos o clúster) | `tar_option_set(controller = crew::crew_controller_local(workers = 4))` |
| Informe que se regenera solo | `tarchetypes::tar_quarto()` |
| Depurar un target que falla | `tar_meta(fields = error)` · `tar_meta(fields = warnings)` |
| Versiones de paquetes fijadas | `renv::snapshot()` → `renv.lock` |
| Semillas reproducibles | cada target recibe su propia semilla a partir de `tar_option_set(seed = )` y de su nombre |
| Seguir cambios en un paquete propio | `tar_option_set(imports = "mi_paquete")` |
| Escenarios o especies como ramas estáticas | `tarchetypes::tar_map()` |
| Varios pipelines en un repositorio | `_targets.yaml` + `Sys.setenv(TAR_PROJECT = "...")` (como `fototrampeo/`) |

## Reproducibilidad y `targets`

- **targets** — orquesta el pipeline y recalcula solo lo que cambia.
  Manual: https://books.ropensci.org/targets/ (artículo: Landau 2021, *JOSS*,
  doi:10.21105/joss.02959)
  - Ramas dinámicas (`pattern = map()`), el mecanismo de "una rama por
    archivo" del taller: https://books.ropensci.org/targets/dynamic.html
  - Computación distribuida con `crew` (varios núcleos o un clúster con
    `tar_option_set(controller = crew::crew_controller_local(workers = 2))`):
    https://books.ropensci.org/targets/crew.html · https://wlandau.github.io/crew/
- **tarchetypes** — atajos sobre targets: `tar_files_input()` (seguir archivos
  de entrada, el que usa este repo), `tar_files()` (archivos generados por el
  propio pipeline), `tar_quarto()` (informes que se regeneran solos).
  https://docs.ropensci.org/tarchetypes/
- **renv** — fija versiones de paquetes (`renv.lock`).
  https://rstudio.github.io/renv/

---

### Lecturas recomendadas
- Pérez-Granados (2023, *Ibis*): BirdNET — aplicaciones, rendimiento y
  *pitfalls*. Buen contrapunto para no vender BirdNET como caja mágica.
- Thompson et al. (2025, *Ibis*): marco de post-procesado para evaluar la
  exactitud de las identificaciones de BirdNET y la composición de comunidades.
- Culina et al. (2020, *PLOS Biology*): *Low availability of code in ecology:
  A call for urgent action*. En 14 revistas de ecología con política de código,
  solo el 27 % de los artículos compartía el código y el 21 % datos y código
  completos. doi:10.1371/journal.pbio.3000763
- Open Science Collaboration (2015, *Science*): reproducibilidad en ciencia
  empírica — motivación para usar pipelines reproducibles.
  doi:10.1126/science.aac4716
- Wilson et al. (2017, *PLOS Comput. Biol.*): *Good enough practices in
  scientific computing*. doi:10.1371/journal.pcbi.1005510
- Alston & Rick (2021, *Bull. Ecol. Soc. Am.*): *A beginner's guide to
  conducting reproducible research*. doi:10.1002/bes2.1801
