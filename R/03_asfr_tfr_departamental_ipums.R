# =====================================================================
# 03_asfr_tfr_departamental_ipums.R — ASFR y TFR por departamento, 1958-2005
#
# Método de hijos propios (Reid et al. 2020) con microdatos IPUMS y
# tablas de supervivencia departamentales. Requiere: extracto IPUMS en
# data/ y las tablas ProbSurv generadas por 01_build_life_tables.R.
# Los departamentos siguen las agrupaciones de IPUMS (ver 00_setup.R).
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

fulldata <- fulldata %>%
  mutate(
    department_code = as.character(GEOLEV1),
    department      = unname(department_labels[department_code])
  )

# ---------------------------------------------------------------------
# 1. EDAD DE LA MADRE AL NACIMIENTO (vía MOMLOC)
# ---------------------------------------------------------------------
if (!"mother_age_at_birth" %in% names(fulldata)) {
  fulldata <- add_mother_age_at_birth(fulldata)
}

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

  path_child <- file.path(dir_probsurv_children,
                          sprintf("%s_%s_ProbSurv_children.csv", dept_name, yr))
  path_women <- file.path(dir_probsurv_women,
                          sprintf("%s_%s_WomenProbSurv.csv", dept_name, yr))

  if (!file.exists(path_child) || !file.exists(path_women)) {
    warning(sprintf("Faltan tablas de supervivencia para %s - %s; se omite",
                    dept_name, yr))
    return(NULL)
  }

  fulldata %>%
    filter(YEAR == yr, department == dept_name) %>%
    compute_asfr_retrospective(read_probsurv(path_child),
                               read_probsurv(path_women),
                               census_year = yr) %>%
    mutate(department = dept_name)
}) %>%
  bind_rows()

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

p <- TFR_depto %>%
  filter(year >= 1958) %>%
  ggplot(aes(x = year, y = tfr, color = factor(census_year))) +
  geom_line(linewidth = 0.4) +
  scale_color_viridis_d(name = "Censo") +
  facet_wrap(~department) +
  labs(x = "Año", y = "TFR",
       title = "TFR departamental, Colombia 1958-2005") +
  theme_minimal()

ggsave(file.path(dir_graf_resumen, "TFR_departamental_1958_2005.png"),
       p, width = 14, height = 10, dpi = 300)

# Una gráfica por departamento (comparando contra el promedio nacional)
tfr_nacional_ref <- TFR_depto %>%
  group_by(year) %>%
  summarise(tfr = mean(tfr, na.rm = TRUE), .groups = "drop")

for (dept in unique(TFR_depto$department)) {
  p_d <- TFR_depto %>%
    filter(department == dept, year >= 1958) %>%
    ggplot(aes(x = year, y = tfr)) +
    geom_line(aes(color = "Departamento")) +
    geom_line(data = tfr_nacional_ref %>% filter(year >= 1958),
              aes(color = "Promedio nacional"), linetype = "dashed") +
    scale_color_manual(name = NULL,
                       values = c("Departamento" = "#440154",
                                  "Promedio nacional" = "grey50")) +
    labs(x = "Año", y = "TFR", title = sprintf("TFR: %s", dept)) +
    theme_minimal()

  ggsave(file.path(dir_graf_tfr_dpto,
                   sprintf("TFR_%s_vs_National.png", dept)),
         p_d, width = 8, height = 5, dpi = 300)
}

cat("Resultados guardados en", output_dir, "\n")
