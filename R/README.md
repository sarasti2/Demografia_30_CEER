# Scripts del proyecto

Correr desde la raíz del repositorio. Todos cargan `00_setup.R`, que instala y carga los paquetes necesarios con `pacman`, define las rutas a `data/` (ver `data/README.md`) y las funciones compartidas.

La primera vez que se corre un script con datos IPUMS, `prepare_ipums()` lee el extracto, construye el departamento y el vínculo madre-hijo, y guarda el resultado en `data/ipums_prepared.rds`; las corridas siguientes lo leen de ahí. Si cambias el extracto, usa `prepare_ipums(refresh = TRUE)` o borra ese archivo.

Cada script libera los microdatos apenas deja de necesitarlos y termina con `clean_session()`, que borra del entorno todo lo que no venga de `00_setup.R` y ejecuta `gc()`. Así se pueden correr todos seguidos sin acumular memoria.

| Script | Descripción |
|---|---|
| `00_setup.R` | Rutas, diccionarios de departamentos y funciones compartidas (lectura de datos, vinculación madre-hijo, ASFR retrospectiva) |
| `01_asfr_tfr_nacional_ipums.R` | ASFR y TFR nacional 1958-2005 (censos IPUMS) |
| `02_asfr_tfr_departamental_ipums.R` | ASFR y TFR departamental 1958-2005 (censos IPUMS) |
| `03_asfr_tfr_nacional_2018.R` | ASFR y TFR nacional 2018 (Censo DANE) |
| `04_asfr_tfr_departamental_2018.R` | ASFR y TFR departamental 2018 (Censo DANE) |
| `05_fcc_ipums.R` | Fecundidad Cohortal Completada y % de mujeres sin hijos (IPUMS) |
| `06_fcc_2018_dane.R` | Fecundidad Cohortal Completada y % de mujeres sin hijos (Censo DANE 2018) |
| `07_densidad_fecundidad.R` | Cruce entre densidad poblacional (`POPDENSGEO1` de IPUMS) y TFR departamental; grafica la dispersión por año censal |
| `08_indicadores_asfr.R` | Descomposición del TFR en las ASFR por etapa reproductiva; grafica el nivel y la participación porcentual, nacional, regional y departamental |
| `09_figuras_tfr_fcc.R` | Figuras de TFR, FCC y mujeres sin hijos: nacionales, una por departamento y una por región, a partir de las tablas de `01` a `06` |
| `10_descarga_migracion_geih.R` | Descarga del DANE los ZIP mensuales del Módulo de Migración GEIH (2012, 2019) y de la GEIH marco 2018 (2022, 2024). Omite los que ya existen y abren bien |
| `11_flujos_migracion_geih.R` | Flujos interdepartamentales a 5 años y a 1 año, tasas por departamento y réplica de Acosta y Gu (2022) para 2019 |
| `12_figuras_migracion_chord.R` | Diagramas de cuerdas de los flujos de `11`, por departamento y por región, y panel con los cuatro años |

Los scripts `01` a `06` replican los cálculos originales del proyecto; `07` y `08` son análisis adicionales y producen sus propias figuras. Los scripts `10` a `12` forman el módulo de migración, independiente del de fecundidad: no usan sus datos ni sus tablas, solo las rutas y las regiones de `00_setup.R`.

Los scripts `01` a `06` solo calculan y exportan tablas a `output/tablas/`; sus figuras se producen en `09_figuras_tfr_fcc.R`, que lee esas tablas. Así se pueden ajustar las figuras sin volver a procesar los microdatos. Si falta alguna tabla, `09` omite esa sección con un aviso en vez de fallar.

Script auxiliar (utilidad, fuera de la secuencia de análisis):

| Script | Descripción |
|---|---|
| `aux_build_cnpv2018_parquet.R` | Consolida los 33 `.DTA` departamentales del Censo 2018 en `data/Censo_2018/CNPV2018_5PER_A2.parquet` |

## Orden de ejecución

Lo más simple es correr todo de una vez desde la raíz del repositorio:

```r
source("run_all.R")
```

El `09` toma la descomposición por etapa del `08` para dibujar el TFR departamental, así que el orden importa: si falta `Indicadores_ASFR.xlsx`, el TFR sale como líneas simples y el script avisa.

`run_all.R` ejecuta los scripts en orden, omite la consolidación del Censo 2018 si el Parquet ya existe, y al final imprime un resumen con el estado y la duración de cada uno (si alguno falla, sigue con los demás y lo reporta).

`run_all.R` sigue el orden numérico. Las dependencias son: `aux_build_cnpv2018_parquet.R` (una sola vez) → `01` y `02` (requieren el extracto IPUMS) → `03`, `04` y `06` (requieren el Parquet del CNPV 2018) → `05` (IPUMS) → `07` y `08`, que parten de las tablas ya generadas → `09`, que produce las figuras de TFR, FCC y mujeres sin hijos → `10` (descarga, solo la primera vez) → `11` → `12`.

En migración, `11` guarda en `data/GEIH_migracion/intermedio/` un extracto comprimido de cada año, así que las corridas siguientes no vuelven a descomprimir los ZIP. Si cambian los ZIP, hay que borrar esos archivos.

Los scripts de 2018 leen únicamente `data/Censo_2018/CNPV2018_5PER_A2.parquet`, así que el auxiliar debe correrse antes que ellos.

Las tablas de supervivencia de `data/ProbSurv_children/` y `data/ProbSurv_woman/` ya están construidas para los 22 departamentos y los cinco años censales (1973, 1985, 1993, 2005 y 2018).

## Estructura de salida (`output/`)

Cada carpeta de indicador tiene dentro `departamental/`, con una figura por departamento contra la serie nacional, y `regional/`, con una figura por región. La figura regional no es una serie agregada de la región: tiene un panel por cada departamento que la compone, con la serie nacional repetida de fondo, para poder compararlos entre sí.

```
output/
├── tablas/                      # Excel (TFR, ASFR, FCC)
│   └── migracion/               # flows_{5y|1y}_{año}.csv, réplica y flujos_migracion_geih.xlsx
└── graficas/
    ├── resumen/                 # gráficas agregadas (nacional, facetas, series)
    ├── tfr/
    │   ├── departamental/       # TFR_{depto}_vs_National.png
    │   └── regional/            # TFR_{region}.png, con un panel por depto
    ├── fcc/
    │   ├── departamental/       # FCC_{depto}_vs_National.png, FCC_cond_...
    │   └── regional/
    ├── tfr_vs_fcc/
    │   ├── departamental/       # comparaciones TFR vs FCC
    │   └── regional/
    ├── tfr_asfr_descomposicion/
    │   ├── departamental/       # descomposición del TFR en ASFR por etapa
    │   └── regional/
    ├── sin_hijos/
    │   ├── departamental/       # infecundidad definitiva por cohorte
    │   └── regional/
    └── migracion/               # chord_{5y|1y}_{año}[_regiones].png, chord_5y_panel[_regiones].png
```

## Estilo de las gráficas

`00_setup.R` define las convenciones visuales del proyecto, para que todas las figuras salgan iguales:

- `theme_fecundidad()`: `theme_minimal` con título centrado en negrilla, leyenda abajo sin título y sin grilla menor. En las figuras con paneles, cada uno va enmarcado con borde gris, separado del vecino y con su nombre sobre una franja gris, para que se lean como unidades distintas.
- Serie nacional en línea negra punteada; intervalos de confianza como banda gris con borde; series múltiples con `col_series(n)`, que devuelve tantos colores como series haya.
- En las comparaciones de dos series (departamento contra total nacional) se usa `col_dpto` (azul) y `col_total` (rojo), con línea y puntos.
- El TFR departamental y regional no es una línea sino el área apilada de la descomposición por etapa, en `col_etapas_pastel`, con la línea nacional en rojo encima. El alto del área es el TFR del departamento, así que se leen a la vez el nivel, la composición por edad de la madre y la distancia contra el país. `col_etapas` (tonos fuertes) queda para las figuras del `08`, donde la descomposición es el tema y no el fondo.
- `escala_anios()` fija las marcas del eje de años cada cinco.
- `escala_fecundidad()` fija el eje vertical de 0 a 12 y dibuja la línea punteada del nivel de reemplazo (`tasa_reemplazo`, 2,1). Se aplica en todas las figuras departamentales y regionales de TFR, FCC y composición por etapas, para que sean comparables entre sí.
- `escala_sin_hijos()` (en `09`) hace lo mismo con la infecundidad definitiva: eje de 0 a 25%.
- `marcas_planificacion()` añade una línea vertical gris punteada en 1965, la creación de Profamilia, a las figuras en años calendario. `marca_cohorte()` hace lo propio en las figuras por cohorte, sobre la cohorte de 1930, que cumple 35 años en 1965 y es la última poco expuesta a esa medida. Las dos funciones ponen la explicación en el pie de la figura.
- Las figuras de FCC arrancan en la cohorte 1920 (`cohorte_inicial`); las anteriores se estiman con muy pocas mujeres.

## Notas metodológicas

Las decisiones metodológicas de fecundidad y migración (definiciones, supuestos, ajustes y limitaciones), con las figuras que las ilustran, están en [`DECISIONES_METODOLOGICAS.md`](../DECISIONES_METODOLOGICAS.md).
