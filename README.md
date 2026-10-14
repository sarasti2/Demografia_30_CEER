# Demografía 30 CEER 
[!CAUTION]
El repositorio aún esta en construcción.

Estimación de la Tasa Global de Fecundidad (TGF), las Tasas Específicas de Fecundidad por Edad (ASFR) y la Fecundidad Cohortal Completada (FCC) para Colombia, a nivel nacional y departamental, 1958–2018, usando microdatos censales y el método de hijos propios (Reid et al., 2020).

## Estructura del repositorio

```
.
├── R/                 # Scripts del proyecto (ver R/README.md)
├── data/              # Microdatos crudos 
├── output/
│   ├── tablas/        # Resultados en Excel (TGF, ASFR, FCC)
│   └── graficas/      # Figuras (resumen, por departamento, TGF vs FCC)
└── README.md
```

## Cómo replicar los resultados

1. Descargar los datos siguiendo las instrucciones de `data/README.md`. Tener en cuenta que la aprobación de la cuenta de IPUMS puede tardar de 2 a 3 semanas; conviene solicitarla con anticipación.
2. Desde la raíz del repositorio, correr los scripts de `R/` en orden:
   `01_build_life_tables.R` → `02` y `03` (censos IPUMS) → `04` y `06` (censo DANE 2018) → `05` (FCC IPUMS).
3. Los resultados quedan en `output/tablas/` y `output/graficas/`.
4. El capítulo (`Documento/main.tex`) y las diapositivas (`Documento/slides.tex`) se compilan con `pdflatex` + `bibtex` desde la carpeta `Documento/` y leen las figuras directamente de `output/graficas/`.

## Requisitos

R con los paquetes: `dplyr`, `tidyr`, `ggplot2`, `ipumsr`, `viridis`, `openxlsx`, `readstata13`.

Para fijar versiones exactas de los paquetes se recomienda [`renv`](https://rstudio.github.io/renv/):

```r
install.packages("renv")
renv::init()
renv::snapshot()
```

Cualquier colaborador reproduce el entorno con `renv::restore()`.

## Licencia de los datos

Los microdatos de IPUMS y DANE están sujetos a sus propios términos de uso, que prohíben la redistribución. Cada usuario debe descargarlos directamente desde la fuente (ver `data/README.md`). Por eso la carpeta `data/` no se incluye en el repositorio.
