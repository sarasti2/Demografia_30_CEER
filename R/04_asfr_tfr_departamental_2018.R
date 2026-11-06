# =====================================================================
# 04_asfr_tfr_departamental_2018.R — ASFR y TFR por departamento,
# Censo 2018
#
# Censo DANE 2018 (CNPV): https://microdatos.dane.gov.co/index.php/catalog/643
#
# El CNPV 2018 no trae vínculo madre-hijo ni edad simple: la edad es el
# punto medio del intervalo quinquenal y el vínculo madre-hijo se imputa
# con reglas de parentesco (ver impute_momloc() en 00_setup.R). Por eso
# las estimaciones de 2018 no son estrictamente comparables con las de
# los censos IPUMS. Los departamentos siguen las agrupaciones de IPUMS.
#
# Se producen dos conjuntos de resultados:
#  1. Versión retrospectiva con ajustes por mortalidad y no-vinculados,
#     análoga a la de los censos IPUMS.
#  2. ASFR quinquenal con hijos corresidentes, sin ajustes. Mezcla
#     fecundidad de varios años, así que es solo una referencia.
#
# Requiere data/CNPV2018_5PER_A2.parquet (ver aux_build_cnpv2018_parquet.R).
# =====================================================================

source("R/00_setup.R")

YEAR_SEL <- 2018

# ---------------------------------------------------------------------
# 1. CARGAR Y PREPARAR EL CENSO 2018
# ---------------------------------------------------------------------
fulldata <- prepare_censo_2018()

# ---------------------------------------------------------------------
# 2. ASFR RETROSPECTIVA POR DEPARTAMENTO
#    (cada departamento con su propia tabla de supervivencia)
# ---------------------------------------------------------------------
res_dpto <- fulldata %>%
  rename(AGE = age_mid, SEX = p_sexo) %>%
  filter(!is.na(department)) %>%
  group_split(department) %>%
  lapply(function(block) {

    dept_name <- block$department[1]
    cat("Procesando:", dept_name, "-", YEAR_SEL, "\n")

    ps <- read_probsurv_dpto(dept_name, YEAR_SEL)

    compute_asfr_retrospective(block, ps$child, ps$women,
                               census_year = YEAR_SEL) %>%
      mutate(department = dept_name)
  }) %>%
  bind_rows() %>%
  aggregate_asfr_tfr(group_vars = "department")

ASFR_depto_2018 <- res_dpto$asfr
TFR_depto_2018  <- res_dpto$tfr

# ---------------------------------------------------------------------
# 3. ASFR QUINQUENAL (hijos corresidentes, sin ajustes)
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

# Los microdatos ya no se necesitan
rm(fulldata); gc(verbose = FALSE)

# ---------------------------------------------------------------------
# 4. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list(
    "TFR_retro"       = TFR_depto_2018,
    "ASFR_retro"      = ASFR_depto_2018,
    "TFR_quinquenal"  = tfr_5yr,
    "ASFR_quinquenal" = asfr_5yr
  ),
  file = file.path(dir_tablas, "TFR_departamental_2018.xlsx"),
  overwrite = TRUE
)

cat("Resultados guardados en", dir_tablas, "\n")

clean_session()
