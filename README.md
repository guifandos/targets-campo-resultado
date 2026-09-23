# Pipelines reproducibles del campo al resultado con `targets`

Material del taller de 45 minutos de las
[**II Jornadas de Ecoinformática de la AEET**](https://ecoinfaeet.github.io/II_jornadas_ecoinf/)
(jueves 1 de octubre de 2026, 17:15–18:00, Sala Posidonia, Fundación
Biodiversidad, Sevilla), impartido por Guillermo Fandos (Universidad
Complutense de Madrid). Usa un caso de ecoacústica, grabaciones tal y como
salen de la tarjeta SD, para enseñar cómo `targets` orquesta un flujo de
trabajo en R que recalcula solo lo que cambia, procesa cada archivo como una
rama independiente y se puede reproducir con un solo comando.

El caso principal es ecoacústico, y el repositorio incluye un **segundo
proyecto de fototrampeo** (`fototrampeo/`) con el mismo esqueleto: una rama por
tarjeta, QC del reloj de la cámara, eventos independientes y tasas de detección
por 100 cámara-día. Sirve igual para telemetría GPS o capas ráster para modelos
de distribución.

## 1. Antes del taller (imprescindible)

En 45 minutos no hay tiempo para instalar nada. Hazlo en casa:

1. Instala **R** (≥ 4.2, <https://cran.r-project.org>) y, recomendado, **RStudio**.
2. Descarga el material: botón verde **`Code ▾`** → **«Download ZIP»**, o bien

   ```bash
   git clone https://github.com/guifandos/targets-campo-resultado.git
   ```

3. En la consola de R, instala los paquetes (solo una vez):

   ```r
   install.packages(c("targets", "tarchetypes", "tuneR", "seewave", "dplyr",
                      "visNetwork"))   # visNetwork es opcional
   ```

4. Abre `targets-campo-resultado.Rproj` y ejecuta la comprobación:

   ```r
   source("check_setup.R")
   ```

   Si termina con `TODO LISTO`, ya está. Si no, te dice qué falta.

> **Windows:** no pongas la carpeta dentro de OneDrive; la sincronización
> interfiere con la caché de `targets`.

## 2. Durante el taller

Abre `practica.R` y sigue los tres ejercicios:

| Ejercicio | Qué aprendes |
|---|---|
| 1. Mira el pipeline y ejecútalo | `tar_manifest()`, `tar_make()`, `tar_read()`, una rama por archivo |
| 2. Llega una SD nueva | `tar_files_input()` detecta archivos nuevos y solo procesa esas ramas |
| 3. Cambia un umbral de QC | `targets` compara código **y valores**: solo se recalcula lo que cambia de verdad |

El ejercicio 3 lo hace el ponente en directo; puedes repetirlo en casa. Los
extras (zona horaria, join que infla filas, romper la detección de archivos
nuevos, el caso de fototrampeo y adaptarlo a tus datos) están al final del
mismo script.

## 3. Estructura del repositorio

```
targets-campo-resultado/
├── _targets.R          # el pipeline acústico (una rama por archivo de audio)
├── _targets.yaml       # declara el segundo proyecto: fototrampeo
├── practica.R          # ejercicios del taller
├── check_setup.R       # comprobación del equipo antes del taller
├── R/                  # funciones, una por etapa (parse, qc, indices, consolidate)
├── data_raw/           # grabaciones de ejemplo (RAW, solo se añade, no se toca)
├── nueva_descarga/     # la "SD que llega tarde" del ejercicio 2
├── data/sites.csv      # diseño de muestreo (una fila por grabador)
├── output/             # aquí aparece la tabla generada
├── fototrampeo/        # segundo caso: cámaras trampa (ver fototrampeo/README.md)
├── tools/              # scripts que generan los datos sintéticos
└── docs/recursos.md    # targets, herramientas PAM abiertas y lecturas
```

`targets` recalcula solo lo que cambia y `data_raw/` es de solo lectura (solo se
añaden archivos nuevos): eso es lo que hace el flujo reproducible y sostenible
entre temporadas de campo.

## Licencia

CC BY 4.0 (ver `LICENSE`).
