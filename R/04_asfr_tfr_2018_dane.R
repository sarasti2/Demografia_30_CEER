# =====================================================================
# 04_asfr_tfr_2018_dane.R — ASFR y TFR 2018 (nacional y departamental)
#
# Censo DANE 2018 (CNPV): https://microdatos.dane.gov.co/index.php/catalog/643
#
# El CNPV 2018 no trae vínculo madre-hijo ni edad simple, así que:
#  - la edad se aproxima con el punto medio (entero) del intervalo
#    quinquenal, necesario para cruzar con las tablas de supervivencia
#  - el vínculo madre-hijo se imputa con reglas de parentesco
#    (replicando la lógica de asignación de MOMLOC de IPUMS)
#
# Se producen dos conjuntos de resultados:
#  1. Versión retrospectiva con ajustes por mortalidad y no-vinculados,
#     análoga a la de los censos IPUMS (comparable con 02 y 03).
#  2. ASFR quinquenal simple con hijos corresidentes, sin ajustes.
#     Advertencia: mezcla fecundidad de varios años; interpretarla solo
#     como referencia.
# =====================================================================

source("R/00_setup.R")

YEAR_SEL <- 2018

# ---------------------------------------------------------------------
# CARGAR CENSO DANE 2018
# ---------------------------------------------------------------------
fulldata <- read.dta13(
  path_censo_2018,
  select.cols = c("coddpto", "cod_encuestas", "u_vivienda", "p_nrohog",
                  "p_parentescor", "p_nro_per", "p_edadr", "p_sexo"),
  convert.factors = FALSE
) %>%
  mutate(
    household_id = paste0(cod_encuestas, u_vivienda, p_nrohog),
    # Edad simple aproximada: punto medio entero del intervalo
    # quinquenal (0-4 -> 2, 5-9 -> 7, ...); entera para poder cruzar
    # con las tablas de supervivencia
    age_mid      = (p_edadr - 1) * 5 + 2,
    department   = unname(department_labels[dane_to_geolev1[as.character(coddpto)]])
  )

# ---------------------------------------------------------------------
# 1. IMPUTAR VÍNCULO MADRE-HIJO (reglas de parentesco, estilo MOMLOC)
# ---------------------------------------------------------------------
# p_parentescor: 1 jefe, 2 cónyuge, 3 hijo/a, 4 nieto/a, 5 otro pariente
impute_momloc <- function(census) {

  census <- census %>% mutate(momloc = 0L)

  # Candidatas: mujeres del hogar con diferencia de edad plausible
  df_pairs <- census %>%
    inner_join(
      census %>%
        filter(p_sexo == 2) %>%
        select(household_id, mom_pernum = p_nro_per,
               mom_age = age_mid, mom_rel = p_parentescor),
      by = "household_id",
      relationship = "many-to-many"
    ) %>%
    mutate(age_diff = mom_age - age_mid) %>%
    filter(age_diff >= 10, age_diff <= 69)

  apply_rule <- function(census, rule_filter) {
    candidates <- df_pairs %>%
      filter({{ rule_filter }}) %>%
      arrange(household_id, p_nro_per, age_diff) %>%
      distinct(household_id, p_nro_per, .keep_all = TRUE) %>%
      select(household_id, p_nro_per, mom_pernum)

    census %>%
      left_join(candidates, by = c("household_id", "p_nro_per")) %>%
      mutate(momloc = if_else(momloc == 0L & !is.na(mom_pernum),
                              as.integer(mom_pernum), momloc)) %>%
      select(-mom_pernum)
  }

  # Regla 1: hijos del jefe -> jefa o cónyuge mujer
  census <- apply_rule(census, p_parentescor == 3 & mom_rel %in% c(1, 2))
  # Regla 2: nietos -> hija del jefe con 15-44 años de diferencia
  census <- apply_rule(census,
    p_parentescor == 4 & mom_rel %in% c(1, 2) &
      age_diff >= 15 & age_diff <= 44)
  # Regla 3: otros parientes menores de 15 -> mujer con 15-50 de diferencia
  census <- apply_rule(census,
    p_parentescor == 5 & age_mid <= 15 & age_diff >= 15 & age_diff <= 50)

  census %>%
    mutate(momloc = if_else(momloc == p_nro_per, 0L, momloc))
}

# Procesar por departamento (bloques naturales, hogares nunca partidos)
fulldata <- fulldata %>%
  group_split(coddpto) %>%
  lapply(function(block) {
    cat("Imputando momloc - coddpto:", block$coddpto[1], "\n")
    block <- impute_momloc(block)
    block %>%
      left_join(
        block %>% select(household_id, momloc = p_nro_per,
                         mom_age = age_mid),
        by = c("household_id", "momloc")
      ) %>%
      mutate(
        mother_age_at_birth = if_else(momloc != 0 & !is.na(mom_age),
                                      mom_age - age_mid, NA_real_)
      ) %>%
      select(-mom_age)
  }) %>%
  bind_rows()

# ---------------------------------------------------------------------
# 2. VERSIÓN RETROSPECTIVA (análoga a los censos IPUMS, con ajustes)
# ---------------------------------------------------------------------
probsurv_child <- read_probsurv(
  file.path(dir_probsurv_children, "2018_ProbSurv_children.csv"))
probsurv_women <- read_probsurv(
  file.path(dir_probsurv_women, "2018_WomenProbSurv.csv"))

census_std <- fulldata %>%
  rename(AGE = age_mid, SEX = p_sexo)

# Nacional
res_nac <- census_std %>%
  compute_asfr_retrospective(probsurv_child, probsurv_women,
                             census_year = YEAR_SEL) %>%
  aggregate_asfr_tfr()

# Departamental
res_dpto <- census_std %>%
  filter(!is.na(department)) %>%
  group_split(department) %>%
  lapply(function(block) {
    compute_asfr_retrospective(block, probsurv_child, probsurv_women,
                               census_year = YEAR_SEL) %>%
      mutate(department = block$department[1])
  }) %>%
  bind_rows() %>%
  aggregate_asfr_tfr(group_vars = "department")

# ---------------------------------------------------------------------
# 3. ASFR QUINQUENAL SIMPLE (hijos corresidentes, sin ajustes;
#    solo como referencia — ver advertencia en el encabezado)
# ---------------------------------------------------------------------
asfr_5yr <- fulldata %>%
  filter(p_sexo == 2) %>%
  mutate(mother_age_grp = floor(age_mid / 5) * 5 + 2.5) %>%
  count(department, mother_age_grp, name = "women") %>%
  left_join(
    fulldata %>%
      filter(!is.na(mother_age_at_birth)) %>%
      mutate(mother_age_grp =
               floor((age_mid + mother_age_at_birth) / 5) * 5 + 2.5) %>%
      count(department, mother_age_grp, name = "children"),
    by = c("department", "mother_age_grp")
  ) %>%
  mutate(
    children = coalesce(children, 0L),
    asfr_5yr = children / women
  )

tfr_5yr <- asfr_5yr %>%
  group_by(department) %>%
  summarise(tfr = 5 * sum(asfr_5yr, na.rm = TRUE), .groups = "drop")

# ---------------------------------------------------------------------
# 4. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list(
    "TFR_nacional_retro"      = res_nac$tfr,
    "ASFR_nacional_retro"     = res_nac$asfr,
    "TFR_dpto_retro"          = res_dpto$tfr,
    "ASFR_dpto_retro"         = res_dpto$asfr,
    "TFR_dpto_quinquenal"     = tfr_5yr,
    "ASFR_dpto_quinquenal"    = asfr_5yr
  ),
  file = file.path(dir_tablas, "TFR_2018_DANE.xlsx"),
  overwrite = TRUE
)

cat("Resultados guardados en", output_dir, "\n")
