# Demografía 30 CEER: fecundidad y migración interna en Colombia

Código del capítulo "Cambios demográficos departamentales a lo largo de los siglos XX y XXI" (Jaramillo-Echeverri y Sarasti), para el libro de los 30 años del CEER (Banco de la República). El proyecto tiene dos módulos:

1. **Fecundidad.** Tasa Global de Fecundidad (TGF/TFR), Tasas Específicas de Fecundidad por Edad (ASFR) y Fecundidad Cohortal Completada (FCC), nacional, regional y departamental, 1958–2015, con microdatos censales (IPUMS 1973, 1985, 1993, 2005 y CNPV 2018) y el método de hijos propios (Reid et al., 2020).
2. **Migración interna.** Flujos interdepartamentales a 5 años y a 1 año con la GEIH del DANE para 2012, 2019, 2022 y 2024. Replica a Acosta y Gu (2022, DTSERU 304) para 2012 y 2019 y extiende la serie a 2022 y 2024 con la GEIH marco 2018. Los resultados se presentan como matrices origen-destino, tasas por departamento y diagramas de cuerdas.

Las decisiones metodológicas de ambos módulos (definiciones, supuestos, ajustes y limitaciones) están en [`DECISIONES_METODOLOGICAS.md`](DECISIONES_METODOLOGICAS.md).

## Estructura del repositorio

```
.
├── run_all.R                    # Corre todo el proyecto en orden
├── DECISIONES_METODOLOGICAS.md  # Decisiones y supuestos metodológicos
├── R/                           # Scripts del proyecto (ver R/README.md)
├── data/                        # Microdatos (no versionados, ver data/README.md)
│   ├── IPSUM/                   #   extracto IPUMS International
│   ├── Censo_2018/              #   CNPV 2018 (DTA departamentales y Parquet)
│   ├── ProbSurv_children/       #   tablas de supervivencia de los hijos
│   ├── ProbSurv_woman/          #   tablas de supervivencia de las mujeres
│   └── GEIH_migracion/          #   GEIH: módulo de migración, Empalme y marco 2018
├── output/
│   ├── tablas/                  # Excel de fecundidad (TFR, ASFR, FCC)
│   │   └── migracion/           # Flujos origen-destino (CSV) y flujos_migracion_geih.xlsx
│   └── graficas/                # Figuras de fecundidad por indicador
│       └── migracion/           # Diagramas de cuerdas
├── Documento/                   # Presentación (slides.tex) y bibliografía
└── README.md
```

## Cómo replicar los resultados

1. Obtener los datos siguiendo `data/README.md`:
   - IPUMS: la aprobación de la cuenta puede tardar de 2 a 3 semanas; conviene solicitarla con anticipación.
   - CNPV 2018: 33 archivos `.DTA` departamentales del DANE.
   - GEIH: los módulos de migración (2012, 2019) y la GEIH marco 2018 (2022, 2024) los descarga `R/10_descarga_migracion_geih.R`. Los dos ZIP anuales del Empalme (2012 y 2019) se descargan a mano.
2. Desde la raíz del repositorio, correr todo con:

   ```r
   source("run_all.R")
   ```

   Ejecuta los scripts en orden (`00` a `12`), omite los pasos ya hechos (el Parquet del Censo 2018, los ZIP de la GEIH ya descargados) y al final imprime un resumen con el estado y la duración de cada uno. También se pueden correr uno por uno; ver `R/README.md`.
3. Los resultados quedan en `output/tablas/` y `output/graficas/` (los de migración, en sus subcarpetas `migracion/`).
4. Las diapositivas (`Documento/slides.tex`) se compilan con `pdflatex` + `bibtex` desde la carpeta `Documento/` y leen las figuras directamente de `output/graficas/`.

## Requisitos

R con los paquetes:

- Fecundidad: `dplyr`, `tidyr`, `ggplot2`, `viridis`, `ipumsr`, `readstata13`, `readxl`, `arrow` y `openxlsx`.
- Migración: `data.table`, `openxlsx`, `circlize` y, solo si algún archivo del DANE viene en `.dta`, `haven`.

No hace falta instalarlos manualmente: `R/00_setup.R` y los scripts de migración usan [`pacman`](https://cran.r-project.org/package=pacman), que instala los que falten y los carga. La extracción de los ZIP del DANE usa, si `unzip()` de R falla con los nombres con tildes, el `tar.exe` de Windows (o `bsdtar`/`unzip` en Linux y Mac).

Para fijar versiones exactas se puede usar además [`renv`](https://rstudio.github.io/renv/):

```r
install.packages("renv")
renv::init()
renv::snapshot()
```

Cualquier colaborador reproduce el entorno con `renv::restore()`.

## Licencia de los datos

Los microdatos de IPUMS y del DANE (CNPV 2018 y GEIH) están sujetos a sus propios términos de uso. Cada usuario debe descargarlos directamente desde la fuente (ver `data/README.md`). Por eso la carpeta `data/` no se incluye en el repositorio.

## Referencias

- Acosta, K. y Gu, J. (2022). Documentos de Trabajo sobre Economía Regional y Urbana (DTSERU), No. 304. Banco de la República. Base de la réplica de migración y de los diagramas de cuerdas.
- Reid, A., Arulanantham, S. J., Day, J., Garrett, E., Jaadla, H. y Lucas-Smith, M. (2020). *Population Studies*, 74(2). doi:10.1080/00324728.2019.1630563. Base del método de hijos propios.

La bibliografía completa está en `Documento/referencias.bib`.
