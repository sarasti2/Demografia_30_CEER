# =====================================================================
# 02_asfr_tfr_nacional_ipums.R — ASFR y TFR nacional, 1958-2005
#
# Método de hijos propios (Reid et al. 2020) con microdatos IPUMS
# (censos 1973, 1985, 1993, 2005) y tablas de supervivencia.
# Requiere: extracto IPUMS en data/ y las tablas ProbSurv generadas
# por 01_build_life_tables.R.
# =====================================================================

source("R/00_setup.R")

# ---------------------------------------------------------------------
# CARGAR DATOS IPUMS
# ---------------------------------------------------------------------
if (!exists("fulldata")) {
  ddi      <- read_ipums_ddi(path_ipums_ddi)
  fulldata <- read_ipums_micro(ddi) %>%
    mutate(
      across(c(YEAR, PERNUM, MOMLOC, AGE, SEX), as.numeric),
      household_id = paste0(SAMPLE, SERIAL)
    ) %>%
    select(-SAMPLE, -SERIAL)
}

# ---------------------------------------------------------------------
# 1. EDAD DE LA MADRE AL NACIMIENTO (vía MOMLOC)
# ---------------------------------------------------------------------
fulldata <- add_mother_age_at_birth(fulldata)

# ---------------------------------------------------------------------
# 2. ASFR RETROSPECTIVA POR CENSO
# ---------------------------------------------------------------------
asfr_rows <- lapply(sort(unique(fulldata$YEAR)), function(yr) {

  cat("Procesando nacional - Año:", yr, "\n")

  probsurv_child <- read_probsurv(
    file.path(dir_probsurv_children, sprintf("%s_ProbSurv_children.csv", yr)))
  probsurv_women <- read_probsurv(
    file.path(dir_probsurv_women, sprintf("%s_WomenProbSurv.csv", yr)))

  fulldata %>%
    filter(YEAR == yr) %>%
    compute_asfr_retrospective(probsurv_child, probsurv_women,
                               census_year = yr) %>%
    mutate(country = "Colombia")
}) %>%
  bind_rows()

# ---------------------------------------------------------------------
# 3. ASFR Y TFR FINALES (agregando sobre los censos)
# ---------------------------------------------------------------------
res <- aggregate_asfr_tfr(asfr_rows, group_vars = "country")

ASFR_national <- res$asfr
TFR_national  <- res$tfr

# ---------------------------------------------------------------------
# 4. EXPORTAR Y GRAFICAR
# ---------------------------------------------------------------------
write.xlsx(
  list("ASFR" = ASFR_national, "TFR" = TFR_national),
  file = file.path(dir_tablas, "TFR_nacional_1958_2005.xlsx"),
  overwrite = TRUE
)

p <- TFR_national %>%
  filter(year >= 1958) %>%
  ggplot(aes(x = year, y = tfr, color = factor(census_year))) +
  geom_line() +
  geom_point(size = 1) +
  scale_color_viridis_d(name = "Censo") +
  labs(x = "Año", y = "TFR",
       title = "Tasa Global de Fecundidad, Colombia 1958-2005",
       subtitle = "Método de hijos propios, microdatos IPUMS") +
  theme_minimal()

ggsave(file.path(dir_graf_resumen, "TFR_nacional_1958_2005.png"),
       p, width = 9, height = 5, dpi = 300)

cat("Resultados guardados en", output_dir, "\n")
