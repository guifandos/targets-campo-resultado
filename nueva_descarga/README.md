# nueva_descarga — la SD que llega tarde

Dos grabaciones más de **AM01** (06:40 y 06:50 del 1 de mayo de 2026) que no
estaban en la primera copia de la tarjeta. Sirven para el ejercicio de ramas:
cópialas a `data_raw/AM01/`, ejecuta `targets::tar_make()` y comprueba con
`targets::tar_progress_branches()` que solo se procesan los dos archivos nuevos.

Mismo formato que `data_raw/` (8 kHz, mono, 16 bit, 10 s, campo *Comment* al
estilo AudioMoth). Son sintéticos y se generan con `tools/generar_sd_nueva.R`.

Para volver al estado inicial, borra esas dos copias de `data_raw/AM01/` y
vuelve a ejecutar `tar_make()`.
