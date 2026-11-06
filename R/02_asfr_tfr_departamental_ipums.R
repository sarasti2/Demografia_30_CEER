# =====================================================================
# 02_asfr_tfr_departamental_ipums.R — ASFR y TFR por departamento, 1958-2005
#
# Método de hijos propios (Reid et al. 2020) con microdatos IPUMS y
# tablas de supervivencia departamentales. Requiere: extracto IPUMS en
# data/IPSUM/ y las tablas de data/ProbSurv_children/ y
# data/ProbSurv_woman/.
# Los departamentos siguen las agrupaciones de IPUMS (ver 00_setup.R).
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
    compute_asfr_retrospective(ps$child, ps$women, census_year = yr) %>%
    mutate(department = dept_name)
}) %>%
  bind_rows()

# Los microdatos ya no se necesitan
rm(fulldata, combos); gc(verbose = FALSE)

# ---------------------------------------------------------------------
# 3. ASFR Y TFR FINALES
# ---------------------------------------------------------------------
res <- aggregate_asfr_tfr(asfr_rows, group_vars = "department")

ASFR_depto <- res$asfr
TFR_depto  <- res$tfr

# ---------------------------------------------------------------------
# 4. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list("ASFR" = ASFR_depto, "TFR" = TFR_depto),
  file = file.path(dir_tablas, "TFR_departamental_1958_2005.xlsx"),
  overwrite = TRUE
)

cat("Tablas guardadas en", dir_tablas, "\n")

clean_session()
