# =====================================================================
# 05_fcc_ipums.R — Fecundidad Cohortal Completada (FCC/CCF), IPUMS
#
# Mujeres de 50-65 años en cada censo (fecundidad ya completada),
# usando CHBORN (hijos nacidos vivos) de IPUMS. Las mujeres con CHBORN
# faltante o desconocido (NA/98/99) se excluyen y se reporta cuántas
# fueron. Incluye también el % de mujeres sin hijos (15-54).
# =====================================================================

source("R/00_setup.R")

# ---------------------------------------------------------------------
# CARGAR DATOS IPUMS
# ---------------------------------------------------------------------
if (!exists("fulldata")) {
  ddi      <- read_ipums_ddi(path_ipums_ddi)
  fulldata <- read_ipums_micro(ddi) %>%
    mutate(
      across(c(YEAR, AGE, SEX, CHBORN), as.numeric),
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
# 1. BASE FCC: mujeres 50-65 con CHBORN válido
# ---------------------------------------------------------------------
women_all <- fulldata %>%
  filter(SEX == 2, AGE >= 50, AGE <= 65)

fcc_base <- women_all %>%
  filter(!is.na(CHBORN), !CHBORN %in% c(98, 99)) %>%
  mutate(cohort = YEAR - AGE)

cat(sprintf(
  "Mujeres 50-65: %d | excluidas por CHBORN faltante/98/99: %d (%.1f%%)\n",
  nrow(women_all), nrow(women_all) - nrow(fcc_base),
  100 * (1 - nrow(fcc_base) / nrow(women_all))
))

# ---------------------------------------------------------------------
# 2. FCC (total y condicional a ser madre), por nivel de agregación
# ---------------------------------------------------------------------
compute_fcc <- function(base, group_vars) {
  fcc_all <- base %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      women          = n(),
      total_children = sum(CHBORN),
      fcc_all        = total_children / women,
      .groups = "drop"
    )

  fcc_cond <- base %>%
    filter(CHBORN >= 1) %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      mothers  = n(),
      fcc_cond = sum(CHBORN) / mothers,
      .groups = "drop"
    )

  left_join(fcc_all, fcc_cond, by = group_vars)
}

FCC_DEPARTAMENTAL <- compute_fcc(fcc_base, c("department", "cohort"))
FCC_NACIONAL      <- compute_fcc(fcc_base, "cohort")

# ---------------------------------------------------------------------
# 3. % DE MUJERES SIN HIJOS, 15-54 (por censo y edad; agenda del proyecto)
# ---------------------------------------------------------------------
childless <- fulldata %>%
  filter(SEX == 2, AGE >= 15, AGE <= 54,
         !is.na(CHBORN), !CHBORN %in% c(98, 99)) %>%
  group_by(YEAR, AGE) %>%
  summarise(
    women          = n(),
    pct_childless  = 100 * mean(CHBORN == 0),
    .groups = "drop"
  )

childless_dpto <- fulldata %>%
  filter(SEX == 2, AGE >= 15, AGE <= 54,
         !is.na(CHBORN), !CHBORN %in% c(98, 99), !is.na(department)) %>%
  group_by(YEAR, department) %>%
  summarise(
    women         = n(),
    pct_childless = 100 * mean(CHBORN == 0),
    .groups = "drop"
  )

# ---------------------------------------------------------------------
# 4. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list(
    "FCC_Departamental"        = FCC_DEPARTAMENTAL,
    "FCC_Nacional"             = FCC_NACIONAL,
    "SinHijos_15_54_nacional"  = childless,
    "SinHijos_15_54_dpto"      = childless_dpto
  ),
  file = file.path(dir_tablas, "Fecundidad_Cohortal_Completada_IPUMS.xlsx"),
  overwrite = TRUE
)

# Gráficas por departamento: FCC total y condicional vs. nacional
for (dept in unique(na.omit(FCC_DEPARTAMENTAL$department))) {

  base_d <- FCC_DEPARTAMENTAL %>% filter(department == dept)

  p_fcc <- ggplot() +
    geom_line(data = base_d, aes(cohort, fcc_all, color = "Departamento")) +
    geom_line(data = FCC_NACIONAL,
              aes(cohort, fcc_all, color = "Nacional"), linetype = "dashed") +
    scale_color_manual(name = NULL,
                       values = c("Departamento" = "#440154",
                                  "Nacional" = "grey50")) +
    labs(x = "Cohorte de nacimiento", y = "FCC",
         title = sprintf("Fecundidad cohortal completada: %s", dept)) +
    theme_minimal()

  ggsave(file.path(dir_graf_fcc_dpto,
                   sprintf("FCC_%s_vs_National.png", dept)),
         p_fcc, width = 8, height = 5, dpi = 300)

  p_cond <- ggplot() +
    geom_line(data = base_d, aes(cohort, fcc_cond, color = "Departamento")) +
    geom_line(data = FCC_NACIONAL,
              aes(cohort, fcc_cond, color = "Nacional"), linetype = "dashed") +
    scale_color_manual(name = NULL,
                       values = c("Departamento" = "#440154",
                                  "Nacional" = "grey50")) +
    labs(x = "Cohorte de nacimiento", y = "FCC condicional (madres)",
         title = sprintf("FCC condicional: %s", dept)) +
    theme_minimal()

  ggsave(file.path(dir_graf_fcc_dpto,
                   sprintf("FCC_cond_%s_vs_National.png", dept)),
         p_cond, width = 8, height = 5, dpi = 300)
}

cat("Resultados guardados en", output_dir, "\n")
