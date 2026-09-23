# fototrampeo — el mismo esqueleto con otro sensor

Segundo proyecto de `targets` del repositorio: de las tarjetas de tres
cámaras trampa a una tabla de **tasas de detección** (eventos independientes
por 100 cámara-día) por cámara y especie, con los ceros incluidos.

```r
Sys.setenv(TAR_PROJECT = "fototrampeo")   # definido en _targets.yaml
targets::tar_make()
read.csv("fototrampeo/output/tasas_deteccion.csv")
Sys.unsetenv("TAR_PROJECT")                # volver al caso acústico
```

Se ejecuta desde la raíz del repositorio; no hace falta `setwd()`.

| Ecoacústica | Fototrampeo |
|---|---|
| un WAV = una rama | una tarjeta (`etiquetas.csv`) = una rama |
| nombre vs cabecera del WAV | fecha EXIF vs fechas del despliegue |
| BirdNET (proceso externo) | detector tipo MegaDetector + etiquetado (antes del pipeline) |
| umbral de QC de duración | umbral de independencia entre eventos (`indep_min`) |
| `sites.csv` | `despliegues.csv` (con esfuerzo) |

## Datos (sintéticos)

Generados por `tools/generar_fototrampeo.R` (semilla fija). Una fila por foto:
`file`, `datetime_exif` (formato EXIF `YYYY:MM:DD HH:MM:SS`), `species`,
`n_individuals`, `det_conf` (confianza del detector).

- **CT01, CT02:** normales, con disparos en falso y detecciones dudosas.
- **CT03:** cambio de pilas el 6 de mayo; el reloj vuelve a `2000-01-01` y
  esas fotos caen fuera del despliegue. El QC las excluye y el esfuerzo se
  corta en la última foto válida anterior (estimación conservadora: el
  reinicio real pudo ser más tarde, así que se pierde algo de esfuerzo).

## Decisiones del análisis (en `fototrampeo/_targets.R`)

- `indep_min <- 30`: minutos entre eventos independientes. Es una convención
  habitual, no una propiedad biológica. Con 60 min los eventos bajan de 64 a 45.
- `min_conf <- 0.5`: confianza mínima del detector. Calíbrala con una muestra
  revisada a mano.
- La tasa de detección **no es abundancia**: depende de la detectabilidad, del
  área de campeo y de la colocación de la cámara (Sollmann et al. 2013,
  *Biol. Conserv.*). Y con poco esfuerzo (CT03: 3,5 días) es muy inestable.
