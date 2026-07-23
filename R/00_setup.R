# =====================================================================
# 00_setup.R — Configuración común del proyecto
# Proyecto: Fecundidad histórica en Colombia (TFR / ASFR / FCC)
#
# Se carga con source("R/00_setup.R") desde la raíz del repositorio.
# Define las rutas a los datos (ver data/README.md), el diccionario de
# departamentos y las funciones compartidas por los demás scripts.
# =====================================================================

# ---------------------------------------------------------------------
# LIBRERÍAS
# ---------------------------------------------------------------------
library(dplyr)
library(tidyr)
library(ggplot2)
library(ipumsr)
library(readstata13)
library(openxlsx)

# ---------------------------------------------------------------------
# RUTAS (relativas a la raíz del repo; los datos NO se versionan)
# ---------------------------------------------------------------------
data_dir   <- "data"
output_dir <- "output"

# IPUMS International: extracto Colombia 1973, 1985, 1993, 2005
# (descargar datos + DDI, ver data/README.md)
path_ipums_ddi <- file.path(data_dir, "ipumsi_00001.xml")

# Censo DANE 2018 (CNPV): https://microdatos.dane.gov.co/index.php/catalog/643
path_censo_2018 <- file.path(data_dir, "CNPV2018_5PER_A2.dta")

# Tablas de supervivencia (construidas con R/01_build_life_tables.R):
#  - Nacional:      {año}_ProbSurv_children.csv / {año}_WomenProbSurv.csv
#  - Departamental: {departamento}_{año}_ProbSurv_children.csv / ..._WomenProbSurv.csv
dir_probsurv_children <- file.path(data_dir, "ProbSurv_children")
dir_probsurv_women    <- file.path(data_dir, "ProbSurv_woman")

# Subcarpetas de salida:
#   tablas/                       -> archivos Excel
#   graficas/resumen/             -> gráficas agregadas (nacional, heatmaps)
#   graficas/tfr_departamental/   -> TFR por departamento
#   graficas/fcc_departamental/   -> FCC por departamento
#   graficas/tfr_vs_fcc/          -> comparaciones TFR vs FCC
dir_tablas          <- file.path(output_dir, "tablas")
dir_graf_resumen    <- file.path(output_dir, "graficas", "resumen")
dir_graf_tfr_dpto   <- file.path(output_dir, "graficas", "tfr_departamental")
dir_graf_fcc_dpto   <- file.path(output_dir, "graficas", "fcc_departamental")
dir_graf_tfr_vs_fcc <- file.path(output_dir, "graficas", "tfr_vs_fcc")

invisible(lapply(
  c(dir_tablas, dir_graf_resumen, dir_graf_tfr_dpto,
    dir_graf_fcc_dpto, dir_graf_tfr_vs_fcc),
  dir.create, showWarnings = FALSE, recursive = TRUE
))

# ---------------------------------------------------------------------
# DICCIONARIO DE DEPARTAMENTOS (GEOLEV1 de IPUMS)
# Departamentos agrupados como en IPUMS:
#   Bogotá D.C. = Bogotá + Cundinamarca; Bolívar = Bolívar + Sucre;
#   Boyacá = Boyacá + Casanare; Cesar = Cesar + Norte de Santander + Magdalena;
#   Caldas = Caldas + Quindío + Risaralda;
#   Amazonas = Amazonas + Guaviare + Vaupés + Vichada + Guainía
#   (en 1993 la muestra excluye Guainía y Vaupés)
# ---------------------------------------------------------------------
department_labels <- c(
  "170005" = "Antioquia",       "170008" = "Atlántico",
  "170011" = "Bogotá D.C.",     "170013" = "Bolívar",
  "170015" = "Boyacá",          "170018" = "Caquetá",
  "170019" = "Cauca",           "170023" = "Córdoba",
  "170027" = "Chocó",           "170041" = "Huila",
  "170044" = "La Guajira",      "170050" = "Meta",
  "170052" = "Nariño",          "170054" = "Cesar",
  "170066" = "Caldas",          "170068" = "Santander",
  "170073" = "Tolima",          "170076" = "Valle del Cauca",
  "170081" = "Arauca",          "170086" = "Putumayo",
  "170088" = "San Andrés",      "170095" = "Amazonas"
)

# Mapeo coddpto (DIVIPOLA, censo DANE 2018) -> GEOLEV1 (agrupación IPUMS)
dane_to_geolev1 <- c(
  "5"  = "170005", "8"  = "170008",
  "11" = "170011", "25" = "170011",
  "13" = "170013", "70" = "170013",
  "15" = "170015", "85" = "170015",
  "18" = "170018", "19" = "170019", "23" = "170023", "27" = "170027",
  "41" = "170041", "44" = "170044", "50" = "170050", "52" = "170052",
  "54" = "170054", "20" = "170054", "47" = "170054",
  "66" = "170066", "17" = "170066", "63" = "170066",
  "68" = "170068", "73" = "170073", "76" = "170076",
  "81" = "170081", "86" = "170086", "88" = "170088",
  "95" = "170095", "91" = "170095", "97" = "170095",
  "99" = "170095", "94" = "170095"
)

# ---------------------------------------------------------------------
# FUNCIONES COMPARTIDAS
# ---------------------------------------------------------------------

# Lee una tabla de supervivencia y estandariza columnas a (age, probsurv),
# sin importar si el CSV trae Age/ProbSurv, age/probsurv, etc.
read_probsurv <- function(path) {
  stopifnot(file.exists(path))
  df <- read.csv(path)
  names(df) <- tolower(names(df))
  stopifnot(all(c("age", "probsurv") %in% names(df)))
  df %>%
    transmute(age = as.numeric(age), probsurv = as.numeric(probsurv))
}

# Edad de la madre al nacimiento de cada hijo, vía MOMLOC (IPUMS):
# une cada persona con la fila de su madre dentro del hogar
# (PERNUM == MOMLOC) y calcula la diferencia de edades.
add_mother_age_at_birth <- function(df) {
  mothers <- df %>%
    select(household_id, MOMLOC = PERNUM, mother_age_census = AGE)
  df %>%
    left_join(mothers, by = c("household_id", "MOMLOC")) %>%
    mutate(
      mother_age_at_birth = if_else(
        MOMLOC > 0 & !is.na(mother_age_census),
        as.numeric(mother_age_census) - as.numeric(AGE),
        NA_real_
      )
    ) %>%
    select(-mother_age_census)
}

# Método de hijos propios con retro-proyección (own-children method),
# siguiendo Reid et al. (2020), https://doi.org/10.1080/00324728.2019.1630563
#
# census: individuos de UN censo (y un departamento, si aplica) con
#         columnas AGE, SEX y mother_age_at_birth.
# Devuelve filas de nacimientos ajustados por (edad del hijo, edad de la
# madre), con asfr y el año calendario del nacimiento.
compute_asfr_retrospective <- function(census,
                                       probsurv_child,
                                       probsurv_women,
                                       census_year,
                                       max_child_age = 14,
                                       mother_age_range = c(15, 50)) {

  # Proporción de niños vinculados a su madre, por edad del niño
  # (corrige el subconteo por hijos que no viven con la madre / no matched)
  prop_df <- census %>%
    filter(AGE <= max_child_age) %>%
    group_by(AGE) %>%
    summarise(
      prop = mean(!is.na(mother_age_at_birth) & mother_age_at_birth > 0),
      .groups = "drop"
    )

  # Mujeres por edad al censo
  women_by_age <- census %>%
    filter(SEX == 2) %>%
    count(AGE, name = "women")

  # Nacimientos: hijos vinculados por (edad hijo, edad madre al censo)
  births <- census %>%
    filter(
      !is.na(mother_age_at_birth),
      mother_age_at_birth >= mother_age_range[1],
      mother_age_at_birth <= mother_age_range[2],
      AGE <= max_child_age
    ) %>%
    mutate(mother_age_at_census = AGE + mother_age_at_birth) %>%
    count(AGE, mother_age_at_census, mother_age_at_birth, name = "n_child")

  births %>%
    left_join(probsurv_women %>%
                rename(mother_age_at_census = age, prob_census = probsurv),
              by = "mother_age_at_census") %>%
    left_join(probsurv_women %>%
                rename(mother_age_at_birth = age, prob_birth = probsurv),
              by = "mother_age_at_birth") %>%
    left_join(probsurv_child %>%
                rename(AGE = age, prob_child = probsurv),
              by = "AGE") %>%
    left_join(prop_df, by = "AGE") %>%
    left_join(women_by_age, by = c("mother_age_at_census" = "AGE")) %>%
    mutate(
      across(c(prop, prob_child, women),
             ~ ifelse(is.na(.x) | .x == 0, NA_real_, .x)),
      # Supervivencia de la madre entre el nacimiento y el censo
      prob_mother      = prob_census / prob_birth,
      # Ajustes por mortalidad infantil, no-matching y mortalidad materna
      n_child_adjusted = n_child / prop / prob_child,
      women_adjusted   = women / prob_mother,
      asfr             = n_child_adjusted / women_adjusted,
      year             = census_year - 1 - AGE,   # año calendario del nacimiento
      census_year      = census_year
    )
}

# Agrega las filas de compute_asfr_retrospective() a ASFR y TFR.
# group_vars: p. ej. character(0) para nacional, "department" para deptos.
aggregate_asfr_tfr <- function(asfr_rows, group_vars = character(0)) {

  asfr <- asfr_rows %>%
    group_by(across(all_of(group_vars)),
             year, census_year, mother_age_at_birth) %>%
    summarise(
      total_women = sum(women_adjusted,   na.rm = TRUE),
      total_child = sum(n_child_adjusted, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(asfr = total_child / total_women)

  tfr <- asfr %>%
    group_by(across(all_of(group_vars)), year, census_year) %>%
    summarise(tfr = sum(asfr, na.rm = TRUE), .groups = "drop") %>%
    filter(is.finite(tfr), tfr > 0)

  list(asfr = asfr, tfr = tfr)
}
