# =====================================================================
# 01_asfr_tfr_nacional_ipums.R — ASFR y TFR nacional, 1958-2005
#
# Método de hijos propios (Reid et al. 2020) con microdatos IPUMS
# (censos 1973, 1985, 1993, 2005) y tablas de supervivencia.
#
# El ajuste por mortalidad se aplica dentro de cada departamento con su
# propia tabla de supervivencia; el nacional se obtiene sumando los
# nacimientos y las mujeres ya ajustados. La serie resultante tiene un
# único valor por año calendario.
#
# Requiere: extracto IPUMS en data/IPSUM/ y las tablas de
# data/ProbSurv_children/ y data/ProbSurv_woman/.
# =====================================================================

source("R/00_setup.R")

# ---------------------------------------------------------------------
# 1. CARGAR DATOS IPUMS (con departamento y edad de la madre)
# ---------------------------------------------------------------------
fulldata <- prepare_ipums()

# ---------------------------------------------------------------------
# 2. ASFR RETROSPECTIVA POR CENSO x DEPARTAMENTO
# ---------------------------------------------------------------------
combos <- fulldata %>%
  filter(!is.na(department)) %>%
  distinct(YEAR, department)

asfr_rows <- lapply(seq_len(nrow(combos)), function(i) {

  yr        <- combos$YEAR[i]
  dept_name <- combos$department[i]
  cat("Procesando:", dept_name, "-", yr, "\n")

  ps <- read_probsurv_dpto(dept_name, yr)

  fulldata %>%
    filter(YEAR == yr, department == dept_name) %>%
    compute_asfr_retrospective(ps$child, ps$women, census_year = yr)
}) %>%
  bind_rows() %>%
  mutate(country = "Colombia")

# Los microdatos ya no se necesitan
rm(fulldata, combos); gc(verbose = FALSE)

# ---------------------------------------------------------------------
# 3. ASFR Y TFR NACIONALES
# ---------------------------------------------------------------------
res <- aggregate_asfr_tfr(asfr_rows, group_vars = "country")

ASFR_national <- res$asfr
TFR_national  <- res$tfr

# Versión desagregada por censo, para revisar los tramos que se solapan
TFR_national_por_censo <- aggregate_asfr_tfr(
  asfr_rows, group_vars = "country", by_census = TRUE
)$tfr

# ---------------------------------------------------------------------
# 4. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list("ASFR"          = ASFR_national,
       "TFR"           = TFR_national,
       "TFR_por_censo" = TFR_national_por_censo),
  file = file.path(dir_tablas, "TFR_nacional_1958_2005.xlsx"),
  overwrite = TRUE
)

cat("Tablas guardadas en", dir_tablas, "\n")

clean_session()
