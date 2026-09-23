# Pipelines reproducibles del campo al resultado con `targets`

Material del taller de 45 minutos de las
[**II Jornadas de Ecoinformática de la AEET**](https://ecoinfaeet.github.io/II_jornadas_ecoinf/)
(jueves 1 de octubre de 2026, 17:15–18:00, Sala Posidonia, Fundación
Biodiversidad, Sevilla), impartido por Guillermo Fandos (Universidad
Complutense de Madrid).

Parte de datos tal y como salen del campo, las tarjetas SD de grabadores y
cámaras trampa, y con un solo comando los convierte en una tabla lista para
analizar. El pipeline está orquestado con
[`targets`](https://books.ropensci.org/targets/): recalcula solo lo que cambia,
procesa cada archivo como una rama independiente y detecta los archivos nuevos
o modificados.

## Qué aprenderás

- A convertir un análisis en funciones y `tar_target()`, y a dejar que
  `targets` deduzca el grafo de dependencias.
- A procesar **una rama por archivo** (`tar_files_input()` + `pattern = map()`),
  de modo que una SD nueva solo procese sus archivos.
- Por qué `targets` compara **valores** además de código, y qué se recalcula
  realmente al cambiar un umbral.
- A reconocer fallos silenciosos habituales: un listado de carpeta que no ve
  archivos nuevos, relojes que se reinician, joins que inflan filas.

## Los dos casos

| | Ecoacústica | Fototrampeo |
|---|---|---|
| Datos | 2 grabadores, 6 WAV de 10 s | 3 cámaras, 203 fotos etiquetadas |
| Una rama por… | archivo WAV | tarjeta (`etiquetas.csv`) |
| QC | duración, fecha del nombre frente a la cabecera, huecos de calendario | fotos fuera del despliegue (reloj reiniciado), vacías, baja confianza del detector |
| Resultado | `output/tabla_analisis.csv` (5 filas: una por grabación válida) | `fototrampeo/output/tasas_deteccion.csv` (12 filas: cámara × especie, con ceros) |
| Proyecto de `targets` | `_targets.R` (por defecto) | `fototrampeo/_targets.R` (declarado en `_targets.yaml`) |

El mismo esqueleto sirve para telemetría GPS (una rama por individuo) o
modelos de distribución (una rama por especie).

## Empezar

1. Instala **R** (≥ 4.2, <https://cran.r-project.org>) y, recomendado, **RStudio**.
2. Descarga el material: botón verde **`Code ▾`** → **«Download ZIP»**, o bien

   ```bash
   git clone https://github.com/guifandos/targets-campo-resultado.git
   ```

3. Instala los paquetes (solo una vez):

   ```r
   install.packages(c("targets", "tarchetypes", "tuneR", "seewave", "dplyr",
                      "visNetwork"))   # visNetwork es opcional
   ```

4. Abre `targets-campo-resultado.Rproj` y comprueba el equipo:

   ```r
   source("check_setup.R")
   ```

   Ejecuta los dos pipelines en una copia temporal y termina con `TODO LISTO`,
   o te dice qué falta. **Si vienes al taller, hazlo antes:** en 45 minutos no
   hay tiempo para instalar.

> **Windows:** no pongas la carpeta dentro de OneDrive; la sincronización
> interfiere con la caché de `targets`.

## Ejecutar

```r
# Ecoacústica (proyecto por defecto)
targets::tar_make()
read.csv("output/tabla_analisis.csv")

# Fototrampeo (segundo proyecto, sin cambiar de directorio)
Sys.setenv(TAR_PROJECT = "fototrampeo")
targets::tar_make()
read.csv("fototrampeo/output/tasas_deteccion.csv")
Sys.unsetenv("TAR_PROJECT")
```

`targets::tar_visnetwork()` dibuja el grafo de cada proyecto y
`targets::tar_progress_branches()` muestra qué ramas se ejecutaron y cuáles
salieron de la caché.

## Presentación

Las diapositivas del taller, en PDF: [`docs/presentacion.pdf`](docs/presentacion.pdf).

## Ejercicios

Están en `practica.R`, con la salida esperada de cada paso:

| Ejercicio | Qué aprendes |
|---|---|
| 1. Mira el pipeline y ejecútalo | `tar_manifest()`, `tar_make()`, `tar_read()`, una rama por archivo |
| 2. Llega una SD nueva | `tar_files_input()` detecta archivos nuevos y solo procesa esas ramas |
| 3. Cambia un umbral de QC | solo se recalculan las ramas cuyo valor cambia (en el taller, demo en directo) |

Extras para casa: zona horaria incorrecta, un join que infla filas, romper la
detección de archivos nuevos, el caso de fototrampeo (cambiar el umbral de
independencia entre eventos) y adaptarlo a tus datos.

## Adaptarlo a tus datos

**Ecoacústica.** Pon tus WAV en `data_raw/` con **una carpeta por grabador**
(el nombre de la carpeta es el `recorder_id`), una fila por grabador en
`data/sites.csv`, y ajusta los parámetros del principio de `_targets.R` (zona
horaria, duración e intervalo de grabación). Para índices reales, pasa
`fun = compute_indices` a `indices_if_pass()`; `R/indices.R` incluye también un
punto de partida para lanzar BirdNET desde R.

**Fototrampeo.** Una carpeta por cámara en `fototrampeo/data_raw/` con su
`etiquetas.csv` (columnas `file`, `datetime_exif`, `species`, `n_individuals`,
`det_conf`), una fila por cámara en `fototrampeo/data/despliegues.csv`, y ajusta
`camera_tz`, `min_conf` e `indep_min` en `fototrampeo/_targets.R`.

Los umbrales (`min_conf`, `indep_min`, la tolerancia de duración) son
**decisiones del análisis**, no valores recomendados: justifícalos para tu
sistema y comprueba cuánto cambian el resultado. La tasa de detección
(eventos por 100 cámara-día) no es una medida de abundancia; ver
`fototrampeo/README.md` y `docs/recursos.md`.

## Datos de ejemplo

Son datos de demostración, pensados para enseñar el flujo, no para analizar:

- `data_raw/`: 6 WAV cortos con un campo *Comment* al estilo AudioMoth, uno de
  ellos truncado a propósito (ver `data_raw/README.md`).
- `nueva_descarga/` y `fototrampeo/`: **sintéticos**, generados con semilla fija
  por `tools/generar_sd_nueva.R` y `tools/generar_fototrampeo.R`.

## Estructura

```
targets-campo-resultado/
├── _targets.R          # pipeline acústico (una rama por archivo de audio)
├── _targets.yaml       # declara el segundo proyecto: fototrampeo
├── R/                  # funciones del caso acústico (parse, qc, indices, consolidate)
├── data_raw/           # grabaciones de ejemplo (solo se añade, no se toca)
├── data/sites.csv      # diseño de muestreo (una fila por grabador)
├── nueva_descarga/     # la "SD que llega tarde" del ejercicio 2
├── output/             # aquí aparece la tabla del caso acústico
├── fototrampeo/        # segundo caso: cámaras trampa (con su propio README)
├── practica.R          # ejercicios
├── check_setup.R       # comprobación del equipo
├── tools/              # scripts que generan los datos sintéticos
└── docs/               # presentacion.pdf y recursos.md (targets, herramientas, lecturas)
```

## Cómo citar

Si usas o adaptas este material, cítalo así (GitHub también ofrece la cita en
«Cite this repository», a partir de `CITATION.cff`):

> Fandos, G. (2026). *Pipelines reproducibles del campo al resultado con
> targets* [Material docente]. II Jornadas de Ecoinformática de la AEET,
> Sevilla. https://github.com/guifandos/targets-campo-resultado

Y cita `targets`: Landau, W. M. (2021). The targets R package: a dynamic
Make-like function-oriented pipeline toolkit for reproducibility and
high-performance computing. *Journal of Open Source Software*, 6(57), 2959.
doi:10.21105/joss.02959

## Licencia

- **Código** (archivos `.R` y de configuración): [MIT](LICENSE).
- **Textos, documentación y datos de ejemplo**:
  [CC BY 4.0](LICENSE-CONTENT.md).
- Las **imágenes de terceros** de `docs/presentacion.pdf` mantienen su propia
  licencia; los créditos están en la última diapositiva.

Guillermo Fandos · Universidad Complutense de Madrid · gfandos@ucm.es
