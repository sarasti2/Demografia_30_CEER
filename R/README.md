# Scripts del proyecto

Correr desde la raíz del repositorio. Todos cargan `00_setup.R`, que define las rutas a `data/` (ver `data/README.md`) y las funciones compartidas.

| Script | Descripción |
|---|---|
| `00_setup.R` | Rutas, diccionarios de departamentos y funciones compartidas (vinculación madre-hijo, ASFR retrospectiva) |
| `01_build_life_tables.R` | Construye las tablas de probabilidades de supervivencia a partir de las tablas de vida crudas (HLD y DANE) |
| `02_asfr_tfr_nacional_ipums.R` | ASFR y TFR nacional 1958-2005 (censos IPUMS) |
| `03_asfr_tfr_departamental_ipums.R` | ASFR y TFR departamental 1958-2005 (censos IPUMS) |
| `04_asfr_tfr_2018_dane.R` | ASFR y TFR 2018, nacional y departamental (Censo DANE) |
| `05_fcc_ipums.R` | Fecundidad Cohortal Completada y % de mujeres sin hijos (IPUMS) |
| `06_fcc_2018_dane.R` | Fecundidad Cohortal Completada y % de mujeres sin hijos (Censo DANE 2018) |

## Orden de ejecución

`01` (una vez descargadas las tablas de vida crudas) → `02`/`03` (requieren el extracto IPUMS) → `04`/`06` (requieren el CNPV 2018) → `05` (IPUMS).

## Estructura de salida (`output/`)

```
output/
├── tablas/                      # Excel (TFR, ASFR, FCC)
└── graficas/
    ├── resumen/                 # gráficas agregadas (nacional, facetas, heatmaps)
    ├── tfr_departamental/       # TFR_{depto}_vs_National.png
    ├── fcc_departamental/       # FCC_{depto}_vs_National.png, FCC_cond_...
    └── tfr_vs_fcc/              # comparaciones TFR vs FCC por depto
```

## Notas metodológicas

- El método de hijos propios sigue a Reid et al. (2020), con ajustes por mortalidad infantil y materna (tablas de vida) y por hijos no vinculados a su madre en el censo. El rango reproductivo considerado es 15-50 años.
- Los departamentos siguen las agrupaciones de IPUMS (por ejemplo, Bogotá D.C. incluye Cundinamarca); ver el diccionario en `00_setup.R`.
- En el censo 2018 la edad es quinquenal y el vínculo madre-hijo se imputa con reglas de parentesco, por lo que sus estimaciones no son estrictamente comparables con las de los censos IPUMS.
- En la FCC, las mujeres sin información de hijos nacidos vivos se excluyen del cálculo y cada script reporta cuántas fueron.
