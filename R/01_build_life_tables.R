# =====================================================================
# 01_build_life_tables.R — Construcción de tablas de supervivencia
#
# Genera los CSV de probabilidades de supervivencia (ProbSurv_children/
# y ProbSurv_woman/) que usan los scripts de ASFR y TFR.
#
# Fuentes (descargar manualmente, ver data/README.md):
#  - Human Life Table Database (Colombia): https://www.lifetable.de
#    Guardar como: data/lifetables_raw/hld_colombia.csv
#  - DANE, estimaciones del cambio demográfico (tablas de mortalidad
#    departamentales): https://www.dane.gov.co/index.php/estadisticas-por-tema/
#    demografia-y-poblacion/estimaciones-del-cambio-demografico
#    Guardar como: data/lifetables_raw/dane_tablas_mortalidad_dpto.csv
#
# Procedimiento:
#  1. Tomar L(x) de la tabla de vida y dividir por l(0) = 100.000
#     -> probabilidad de sobrevivir del nacimiento a la edad x.
#  2. Promediar por sexo cuando corresponda (niños: ambos sexos;
#     mujeres: solo sexo femenino).
#  3. Para las tablas departamentales, promediar los departamentos que
#     IPUMS agrupa (ver department_groups abajo).
#  4. Exportar un CSV por censo (nacional) o por departamento x censo,
#     con columnas estandarizadas: age, probsurv.
#
# El formato exacto de los archivos crudos varía según la descarga;
# ajustar la sección "LECTURA" a las columnas reales. Las tablas
# quinquenales se des-abrevian con interpolación lineal de L(x).
# =====================================================================

source("R/00_setup.R")

dir_lt_raw <- file.path(data_dir, "lifetables_raw")
dir.create(dir_probsurv_children, showWarnings = FALSE, recursive = TRUE)
dir.create(dir_probsurv_women,    showWarnings = FALSE, recursive = TRUE)

census_years <- c(1973, 1985, 1993, 2005, 2018)

# Agrupaciones departamentales de IPUMS: nombre del grupo -> deptos DANE
department_groups <- list(
  "Antioquia"       = "Antioquia",
  "Atlántico"       = "Atlántico",
  "Bogotá D.C."     = c("Bogotá D.C.", "Cundinamarca"),
  "Bolívar"         = c("Bolívar", "Sucre"),
  "Boyacá"          = c("Boyacá", "Casanare"),
  "Caquetá"         = "Caquetá",
  "Cauca"           = "Cauca",
  "Córdoba"         = "Córdoba",
  "Chocó"           = "Chocó",
  "Huila"           = "Huila",
  "La Guajira"      = "La Guajira",
  "Meta"            = "Meta",
  "Nariño"          = "Nariño",
  "Cesar"           = c("Cesar", "Norte de Santander", "Magdalena"),
  "Caldas"          = c("Caldas", "Quindío", "Risaralda"),
  "Santander"       = "Santander",
  "Tolima"          = "Tolima",
  "Valle del Cauca" = "Valle del Cauca",
  "Arauca"          = "Arauca",
  "Putumayo"        = "Putumayo",
  "San Andrés"      = "San Andrés",
  "Amazonas"        = c("Amazonas", "Guaviare", "Vaupés", "Vichada", "Guainía")
)

# ---------------------------------------------------------------------
# FUNCIONES
# ---------------------------------------------------------------------

# De una tabla de vida (edad, lx o Lx por edad simple) a prob. de
# supervivencia del nacimiento a cada edad: surv(x) = Lx / l0.
lifetable_to_probsurv <- function(lt, radix = 100000) {
  lt %>%
    arrange(age) %>%
    transmute(age = age, probsurv = Lx / radix)
}

# Interpolación lineal de Lx quinquenal a edad simple (alternativa
# simple a MORTPAK/UNABR; revisar sensibilidad de resultados).
unabridge_linear <- function(lt_abridged, max_age = 100) {
  with(lt_abridged, approx(x = age, y = Lx, xout = 0:max_age)) %>%
    as.data.frame() %>%
    rename(age = x, Lx = y)
}

# ---------------------------------------------------------------------
# LECTURA (AJUSTAR a los formatos reales descargados)
# ---------------------------------------------------------------------
# Se espera un archivo largo con columnas:
#   year (año o quinquenio de la tabla), sex ("male"/"female"/"both"),
#   department (solo el archivo DANE), age, Lx
path_hld  <- file.path(dir_lt_raw, "hld_colombia.csv")
path_dane <- file.path(dir_lt_raw, "dane_tablas_mortalidad_dpto.csv")

hld_raw  <- read.csv(path_hld)
dane_raw <- read.csv(path_dane)

# ---------------------------------------------------------------------
# 1. TABLAS NACIONALES: {año}_ProbSurv_children.csv / {año}_WomenProbSurv.csv
# ---------------------------------------------------------------------
for (yr in census_years) {

  # Seleccionar la tabla nacional más cercana al año censal
  lt_year <- hld_raw %>%
    filter(year == yr)  # TODO: si no hay tabla exacta, tomar la más cercana

  # Niños: promedio de ambos sexos
  lt_children <- lt_year %>%
    group_by(age) %>%
    summarise(Lx = mean(Lx), .groups = "drop")

  # Mujeres: solo sexo femenino
  lt_women <- lt_year %>%
    filter(sex == "female") %>%
    select(age, Lx)

  # Des-abreviar si la tabla viene quinquenal
  if (max(diff(sort(unique(lt_children$age)))) > 1) {
    lt_children <- unabridge_linear(lt_children)
    lt_women    <- unabridge_linear(lt_women)
  }

  write.csv(lifetable_to_probsurv(lt_children),
            file.path(dir_probsurv_children,
                      sprintf("%s_ProbSurv_children.csv", yr)),
            row.names = FALSE)
  write.csv(lifetable_to_probsurv(lt_women),
            file.path(dir_probsurv_women,
                      sprintf("%s_WomenProbSurv.csv", yr)),
            row.names = FALSE)
}

# ---------------------------------------------------------------------
# 2. TABLAS DEPARTAMENTALES:
#    {departamento}_{año}_ProbSurv_children.csv / ..._WomenProbSurv.csv
#    (promediando los departamentos agrupados por IPUMS)
# ---------------------------------------------------------------------
for (yr in setdiff(census_years, 2018)) {
  for (grp in names(department_groups)) {

    lt_grp <- dane_raw %>%
      filter(year == yr, department %in% department_groups[[grp]])

    if (nrow(lt_grp) == 0) {
      warning(sprintf("Sin tabla de vida para %s - %s", grp, yr))
      next
    }

    # Promedio entre sexos y luego entre departamentos del grupo
    lt_children <- lt_grp %>%
      group_by(department, age) %>%
      summarise(Lx = mean(Lx), .groups = "drop") %>%     # entre sexos
      group_by(age) %>%
      summarise(Lx = mean(Lx), .groups = "drop")         # entre deptos

    lt_women <- lt_grp %>%
      filter(sex == "female") %>%
      group_by(age) %>%
      summarise(Lx = mean(Lx), .groups = "drop")

    if (max(diff(sort(unique(lt_children$age)))) > 1) {
      lt_children <- unabridge_linear(lt_children)
      lt_women    <- unabridge_linear(lt_women)
    }

    write.csv(lifetable_to_probsurv(lt_children),
              file.path(dir_probsurv_children,
                        sprintf("%s_%s_ProbSurv_children.csv", grp, yr)),
              row.names = FALSE)
    write.csv(lifetable_to_probsurv(lt_women),
              file.path(dir_probsurv_women,
                        sprintf("%s_%s_WomenProbSurv.csv", grp, yr)),
              row.names = FALSE)
  }
}

cat("Tablas de supervivencia generadas en", dir_probsurv_children,
    "y", dir_probsurv_women, "\n")
