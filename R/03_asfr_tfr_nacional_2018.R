# =====================================================================
# 03_asfr_tfr_nacional_2018.R — ASFR y TFR nacional, Censo 2018
#
# El CNPV 2018 no trae vínculo madre-hijo ni edad simple: la edad es el
# punto medio del intervalo quinquenal y el vínculo madre-hijo se imputa
# con reglas de parentesco (ver impute_momloc() en 00_setup.R). Por eso
# las estimaciones de 2018 no son estrictamente comparables con las de
# los censos IPUMS (scripts 01 y 02).
#
# El ajuste por mortalidad se aplica dentro de cada departamento con su
# propia tabla de supervivencia; el nacional se obtiene sumando los
# nacimientos y las mujeres ya ajustados.
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
# ---------------------------------------------------------------------
asfr_rows <- fulldata %>%
  rename(AGE = age_mid, SEX = p_sexo) %>%
  filter(!is.na(department)) %>%
  group_split(department) %>%
  lapply(function(block) {

    dept_name <- block$department[1]
    cat("Procesando:", dept_name, "-", YEAR_SEL, "\n")

    ps <- read_probsurv_dpto(dept_name, YEAR_SEL)

    compute_asfr_retrospective(block, ps$child, ps$women,
                               census_year = YEAR_SEL)
  }) %>%
  bind_rows() %>%
  mutate(country = "Colombia")

# Los microdatos ya no se necesitan
rm(fulldata); gc(verbose = FALSE)

# ---------------------------------------------------------------------
# 3. ASFR Y TFR NACIONALES
# ---------------------------------------------------------------------
res_nac <- aggregate_asfr_tfr(asfr_rows, group_vars = "country")

ASFR_national_2018 <- res_nac$asfr
TFR_national_2018  <- res_nac$tfr

# ---------------------------------------------------------------------
# 4. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list("ASFR" = ASFR_national_2018, "TFR" = TFR_national_2018),
  file = file.path(dir_tablas, "TFR_nacional_2018.xlsx"),
  overwrite = TRUE
)

cat("Resultados guardados en", dir_tablas, "\n")

clean_session()
