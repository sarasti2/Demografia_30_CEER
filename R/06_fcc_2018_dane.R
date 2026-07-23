# =====================================================================
# 06_fcc_2018_dane.R — Fecundidad Cohortal Completada (FCC), Censo 2018
#
# Censo DANE 2018 (CNPV), variable pa1_thnv (total hijos nacidos vivos).
# Mujeres 50-60 (edad quinquenal media) = fecundidad completada. Las
# mujeres con pa1_thnv faltante o desconocido (NA/98/99) se excluyen y
# se reporta cuántas fueron. Incluye también el % de mujeres sin hijos
# (15-54).
# =====================================================================

source("R/00_setup.R")

YEAR_CENSUS <- 2018

# ---------------------------------------------------------------------
# CARGAR CENSO DANE 2018
# ---------------------------------------------------------------------
fulldata <- read.dta13(
  path_censo_2018,
  select.cols = c("coddpto", "cod_encuestas", "u_vivienda", "p_nrohog",
                  "p_nro_per", "p_edadr", "p_sexo", "pa1_thnv"),
  convert.factors = FALSE
) %>%
  mutate(
    age_mid    = (p_edadr - 1) * 5 + 2,
    department = unname(department_labels[dane_to_geolev1[as.character(coddpto)]])
  )

# ---------------------------------------------------------------------
# 1. BASE FCC: mujeres 50-60 con pa1_thnv válido
# ---------------------------------------------------------------------
women_all <- fulldata %>%
  filter(p_sexo == 2, age_mid >= 50, age_mid <= 60)

fcc_base <- women_all %>%
  filter(!is.na(pa1_thnv), !pa1_thnv %in% c(98, 99)) %>%
  mutate(cohort = YEAR_CENSUS - age_mid)

cat(sprintf(
  "Mujeres 50-60: %d | excluidas por pa1_thnv faltante/98/99: %d (%.1f%%)\n",
  nrow(women_all), nrow(women_all) - nrow(fcc_base),
  100 * (1 - nrow(fcc_base) / nrow(women_all))
))

# ---------------------------------------------------------------------
# 2. FCC (total y condicional a ser madre)
# ---------------------------------------------------------------------
compute_fcc <- function(base, group_vars) {
  fcc_all <- base %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      women          = n(),
      total_children = sum(pa1_thnv),
      fcc_all        = total_children / women,
      .groups = "drop"
    )

  fcc_cond <- base %>%
    filter(pa1_thnv >= 1) %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      mothers  = n(),
      fcc_cond = sum(pa1_thnv) / mothers,
      .groups = "drop"
    )

  left_join(fcc_all, fcc_cond, by = group_vars)
}

FCC_2018          <- compute_fcc(fcc_base, c("department", "cohort"))
FCC_2018_NACIONAL <- compute_fcc(fcc_base, "cohort")

# ---------------------------------------------------------------------
# 3. % DE MUJERES SIN HIJOS, 15-54
# ---------------------------------------------------------------------
childless <- fulldata %>%
  filter(p_sexo == 2, age_mid >= 15, age_mid <= 54,
         !is.na(pa1_thnv), !pa1_thnv %in% c(98, 99)) %>%
  group_by(age_mid) %>%
  summarise(
    women         = n(),
    pct_childless = 100 * mean(pa1_thnv == 0),
    .groups = "drop"
  )

childless_dpto <- fulldata %>%
  filter(p_sexo == 2, age_mid >= 15, age_mid <= 54,
         !is.na(pa1_thnv), !pa1_thnv %in% c(98, 99), !is.na(department)) %>%
  group_by(department) %>%
  summarise(
    women         = n(),
    pct_childless = 100 * mean(pa1_thnv == 0),
    .groups = "drop"
  )

# ---------------------------------------------------------------------
# 4. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list(
    "Departamental"           = FCC_2018,
    "Nacional"                = FCC_2018_NACIONAL,
    "SinHijos_15_54_nacional" = childless,
    "SinHijos_15_54_dpto"     = childless_dpto
  ),
  file = file.path(dir_tablas, "Fecundidad_Cohortal_Completada_2018.xlsx"),
  overwrite = TRUE
)

cat("Resultados guardados en", output_dir, "\n")
