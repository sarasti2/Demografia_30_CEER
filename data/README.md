# Datos requeridos

Esta carpeta está vacía en el repositorio a propósito: los microdatos usados tienen licencias que prohíben su redistribución. Descárgalos desde las fuentes oficiales y colócalos en las rutas indicadas abajo.

Estructura final esperada:

```
data/
├── ipumsi_00001.xml               # DDI del extracto IPUMS
├── ipumsi_00001.dat.gz            # Datos del extracto IPUMS
├── CNPV2018_5PER_A2.dta           # Censo DANE 2018
├── lifetables_raw/                # Tablas de vida crudas (HLD y DANE)
├── ProbSurv_children/             # Generada por R/01_build_life_tables.R
└── ProbSurv_woman/                # Generada por R/01_build_life_tables.R
```

## 1. Microdatos IPUMS International (censos Colombia 1973, 1985, 1993, 2005)

- Fuente: https://international.ipums.org/international/
- Crea una cuenta y solicita acceso a los microdatos internacionales. **La aprobación de la cuenta tarda de 2 a 3 semanas**, así que solicítala con anticipación.
- En la descripción del proyecto indica el país (Colombia), el período (1958–2018) y el uso investigativo de los datos.
- Una vez aprobada la cuenta, arma un extracto para Colombia con las muestras de 1973, 1985, 1993 y 2005, incluyendo las variables: `YEAR`, `SAMPLE`, `SERIAL`, `PERNUM`, `MOMLOC`, `AGE`, `SEX`, `GEOLEV1`, `CHBORN`.
- Descarga tanto el archivo de datos como el DDI (metadata) y colócalos en `data/` como `ipumsi_00001.xml` y su archivo de datos correspondiente.
- Usado por: `02_asfr_tfr_nacional_ipums.R`, `03_asfr_tfr_departamental_ipums.R`, `05_fcc_ipums.R`.

## 2. Microdatos Censo DANE 2018 (CNPV)

- Fuente: https://microdatos.dane.gov.co/index.php/catalog/643
- Archivo esperado: `data/CNPV2018_5PER_A2.dta`
- Usado por: `04_asfr_tfr_2018_dane.R`, `06_fcc_2018_dane.R`.

## 3. Tablas de vida (para las probabilidades de supervivencia)

Las probabilidades de supervivencia que usan los scripts se construyen automáticamente con `R/01_build_life_tables.R` a partir de dos fuentes:

- Human Life Table Database (Colombia): https://www.lifetable.de
- Estimaciones del cambio demográfico del DANE (tablas de mortalidad departamentales): https://www.dane.gov.co/index.php/estadisticas-por-tema/demografia-y-poblacion/estimaciones-del-cambio-demografico

Descarga las tablas crudas y colócalas en `data/lifetables_raw/` como:

- `hld_colombia.csv` (nacional, columnas: `year`, `sex`, `age`, `Lx`)
- `dane_tablas_mortalidad_dpto.csv` (departamental, columnas: `year`, `sex`, `department`, `age`, `Lx`)

Al correr `R/01_build_life_tables.R` se generan los archivos de `ProbSurv_children/` y `ProbSurv_woman/` (columnas `age`, `probsurv`):

- Nacional, por año censal: `{año}_ProbSurv_children.csv`, `{año}_WomenProbSurv.csv`
- Departamental: `{departamento}_{año}_ProbSurv_children.csv`, `{departamento}_{año}_WomenProbSurv.csv`

Los nombres de departamento siguen las agrupaciones de IPUMS (Bogotá D.C. incluye Cundinamarca; Bolívar incluye Sucre; Boyacá incluye Casanare; Cesar incluye Norte de Santander y Magdalena; Caldas incluye Quindío y Risaralda; Amazonas incluye Guaviare, Vaupés, Vichada y Guainía).
