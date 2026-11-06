# Datos

Los microdatos no se versionan en el repositorio (licencias de IPUMS y DANE que prohíben la redistribución). Esta guía describe cómo obtenerlos y cómo debe quedar organizada la carpeta.

## Estructura

```
data/
├── IPSUM/
│   ├── ipumsi_00043.xml           # DDI (metadata) del extracto
│   └── ipumsi_00043.dat.gz        # Microdatos IPUMS
├── Censo_2018/
│   ├── Raw/
│   │   └── CNPV2018_5PER_A2_XX.DTA  # Un archivo por departamento (XX = código DIVIPOLA)
│   └── CNPV2018_5PER_A2.parquet     # Consolidado (lo genera el script auxiliar)
├── ProbSurv_children/
│   └── {depto}_{año}_ProbSurv_children.csv
├── ProbSurv_woman/
│   └── {depto}_{año}_WomenProbSurv.csv
└── GEIH_migracion/
    ├── raw/
    │   ├── modulo_2012/           # MM_Mes.zip (febrero a diciembre)
    │   ├── modulo_2019/           # MM_Mes.zip (enero a diciembre)
    │   ├── geih_2022/             # MM_Mes.zip, GEIH marco 2018
    │   ├── geih_2024/             # MM_Mes.zip, GEIH marco 2018
    │   └── empalme/               # GEIH_Empalme_2012.zip, GEIH_Empalme_2019.zip
    ├── intermedio/                # extractos .csv.gz que genera el script 11
    └── referencia/
        └── flows_5y_2019_AcostaGu.csv   # flujos originales para la réplica
```

## 1. Microdatos IPUMS International (censos 1973, 1985, 1993, 2005)

- Fuente: https://international.ipums.org/international/
- Requiere cuenta con acceso aprobado a los microdatos internacionales. **La aprobación tarda de 2 a 3 semanas**, así que conviene solicitarla con anticipación. En la descripción del proyecto hay que indicar el país (Colombia), el período de estudio y el uso investigativo.
- El extracto debe incluir las muestras de Colombia 1973, 1985, 1993 y 2005, con las variables: `YEAR`, `SAMPLE`, `SERIAL`, `PERNUM`, `MOMLOC`, `AGE`, `SEX`, `GEOLEV1`, `CHBORN`, `MARST` (estado civil, para la infecundidad entre alguna vez casadas o unidas) y `POPDENSGEO1` (densidad poblacional, para el script `07`).
- Se descargan dos archivos: los datos (`.dat.gz`) y el DDI (`.xml`). Ambos van en `data/IPSUM/`.
- La ruta al DDI se define en `R/00_setup.R` (`path_ipums_ddi`); si tu extracto tiene otro número, actualízala.
- Usado por: `01_asfr_tfr_nacional_ipums.R`, `02_asfr_tfr_departamental_ipums.R`, `05_fcc_ipums.R` y `07_densidad_fecundidad.R`.

## 2. Microdatos Censo DANE 2018 (CNPV)

- Fuente: https://microdatos.dane.gov.co/index.php/catalog/643
- Se descarga un archivo `.DTA` por departamento (33 en total, unos 17 GB). Todos van en `data/Censo_2018/Raw/` sin renombrar.
- Columnas usadas por el proyecto: `u_dpto`, `cod_encuestas`, `u_vivienda`, `p_nrohog`, `p_parentescor`, `p_nro_per`, `p_edadr`, `p_sexo`, `pa_hnv`, `pa1_thnv`, `p_est_civil`.
- Usado por: `03_asfr_tfr_nacional_2018.R`, `04_asfr_tfr_departamental_2018.R`, `06_fcc_2018_dane.R`.

### Consolidado en Parquet

`R/aux_build_cnpv2018_parquet.R` une los archivos departamentales, se queda solo con las columnas necesarias y genera `data/Censo_2018/CNPV2018_5PER_A2.parquet`. Se corre una sola vez y es requisito de los scripts `03`, `04` y `06`, que leen únicamente ese archivo.

## 3. Tablas de supervivencia

Ya están construidas en `ProbSurv_children/` y `ProbSurv_woman/` (columnas `age`, `probsurv`): 22 departamentos × cinco años censales (1973, 1985, 1993, 2005 y 2018).

Se derivan de las tablas de vida de la Human Life Table Database (https://www.lifetable.de) y de las estimaciones del cambio demográfico del DANE (https://www.dane.gov.co/index.php/estadisticas-por-tema/demografia-y-poblacion/estimaciones-del-cambio-demografico): la probabilidad de supervivencia es L(x) dividido por l(0) = 100.000, promediada por sexo (ambos sexos para las tablas de niños, solo femenino para las de mujeres) y luego entre los departamentos que IPUMS agrupa.

Los scripts solo usan las tablas departamentales: los resultados nacionales se obtienen agregando los departamentos ya ajustados.

Los nombres de departamento siguen las agrupaciones de IPUMS: Bogotá D.C. incluye Cundinamarca; Bolívar incluye Sucre; Boyacá incluye Casanare; Cesar incluye Norte de Santander y Magdalena; Caldas incluye Quindío y Risaralda; Amazonas incluye Guaviare, Vaupés, Vichada y Guainía.

## 4. GEIH del DANE (migración interna)

Usada por `10_descarga_migracion_geih.R`, `11_flujos_migracion_geih.R` y `12_figuras_migracion_chord.R`. Fuente: https://microdatos.dane.gov.co

- **Módulo de Migración 2012 y 2019** (catálogos 634 y 641) y **GEIH marco 2018 de 2022 y 2024** (catálogos 771 y 819): los descarga `10_descarga_migracion_geih.R`, un ZIP por mes, en `raw/modulo_{año}/` y `raw/geih_{año}/`. El módulo de 2012 no tiene enero. Los meses de 2022 y 2024 pesan unos 65 MB cada uno.
- **Empalme 2012 y 2019**: se descargan a mano desde el catálogo de la GEIH Empalme del DANE y se guardan como `raw/empalme/GEIH_Empalme_2012.zip` y `raw/empalme/GEIH_Empalme_2019.zip` (unos 250 MB cada uno). El módulo de migración no trae el departamento de residencia, así que `11` lo toma de Características generales del Empalme.
- **Referencia de la réplica**: `referencia/flows_5y_2019_AcostaGu.csv`, con los flujos originales de Acosta y Gu (2022) a 5 años para 2019 (columnas `out`, `in`, `val`). Si falta, `11` corre igual y solo omite la comparación.
- Variables usadas: llaves `DIRECTORIO`, `SECUENCIA_P`, `ORDEN`; `DPTO`; factores `FEX_C_2011`, `FEX_C` (Empalme) y `FEX_C18`; migración `P6074`, `P6075`, `P6076`, `P6076S1` (2012), `P753`, `P753S1`, `P755`, `P755S1` (2019) y `P3382`, `P3382S1`, `P3384`, `P3384S1` (2022, 2024).
- Los ZIP del DANE traen nombres con tildes en codificaciones distintas. Si `unzip()` de R falla con ellos, `11` usa el `tar.exe` de Windows (o `bsdtar`/`unzip` en Linux y Mac).

## Verificación antes de correr los scripts

- **Censo 2018**: deben estar los 33 archivos `CNPV2018_5PER_A2_XX.DTA` en `Censo_2018/Raw/`. `aux_build_cnpv2018_parquet.R` avisa si falta alguno.
- **Tablas de supervivencia**: 110 archivos departamentales en cada carpeta (22 departamentos × 5 años censales).
- **GEIH**: 11 ZIP en `modulo_2012/`, 12 en `modulo_2019/`, `geih_2022/` y `geih_2024/`, y los dos ZIP del Empalme en `empalme/`. `10` informa al final qué meses no pudo descargar.
