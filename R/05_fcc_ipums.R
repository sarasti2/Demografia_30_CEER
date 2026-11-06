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
fulldata <- prepare_ipums() %>%
  mutate(CHBORN = as.numeric(CHBORN))

# ---------------------------------------------------------------------
# 1. BASE FCC: mujeres 50-65 con CHBORN válido
# ---------------------------------------------------------------------
women_all <- fulldata %>%
  filter(SEX == 2, AGE >= 50, AGE <= 65)

fcc_base <- women_all %>%
  filter(!is.na(CHBORN), !CHBORN %in% c(98, 99)) %>%
  mutate(
    cohort = YEAR - AGE,
    # "Alguna vez casada o unida": todo estado civil que no sea soltera.
    # MARST (IPUMS): 1 soltera, 2 casada/union, 3 separada/divorciada,
    # 4 viuda, 0/9 sin dato. Se toman 2-4; el resto queda fuera del
    # subgrupo de casadas (pero sigue contando en el total).
    ever_partnered = as.numeric(MARST) %in% c(2, 3, 4)
  )

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
      # mujeres alguna vez casadas o unidas (para la infecundidad de casadas)
      women_cas      = sum(ever_partnered),
      .groups = "drop"
    )

  fcc_cond <- base %>%
    filter(CHBORN >= 1) %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      mothers     = n(),
      fcc_cond    = sum(CHBORN) / mothers,
      # madres alguna vez casadas o unidas
      mothers_cas = sum(ever_partnered),
      .groups = "drop"
    )

  left_join(fcc_all, fcc_cond, by = group_vars)
}

FCC_DEPARTAMENTAL <- compute_fcc(fcc_base, c("department", "cohort"))
FCC_NACIONAL      <- compute_fcc(fcc_base, "cohort")

# ---------------------------------------------------------------------
# 3. % DE MUJERES SIN HIJOS, 15-54
# ---------------------------------------------------------------------
childless_base <- fulldata %>%
  filter(SEX == 2, AGE >= 15, AGE <= 54,
         !is.na(CHBORN), !CHBORN %in% c(98, 99)) %>%
  mutate(cohort = YEAR - AGE)

# Por censo y edad
childless <- childless_base %>%
  group_by(YEAR, AGE) %>%
  summarise(
    women          = n(),
    pct_childless  = 100 * mean(CHBORN == 0),
    .groups = "drop"
  )

# Por cohorte: cada censo aporta un tramo, lo que arma una serie larga
childless_cohorte <- childless_base %>%
  group_by(YEAR, cohort) %>%
  summarise(
    women         = n(),
    pct_childless = 100 * mean(CHBORN == 0),
    .groups = "drop"
  )

childless_dpto <- childless_base %>%
  filter(!is.na(department)) %>%
  group_by(YEAR, department) %>%
  summarise(
    women         = n(),
    pct_childless = 100 * mean(CHBORN == 0),
    .groups = "drop"
  )

# Los microdatos ya no se necesitan
rm(fulldata, women_all, fcc_base, childless_base); gc(verbose = FALSE)

# ---------------------------------------------------------------------
# 4. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list(
    "FCC_Departamental"        = FCC_DEPARTAMENTAL,
    "FCC_Nacional"             = FCC_NACIONAL,
    "SinHijos_15_54_nacional"  = childless,
    "SinHijos_15_54_cohorte"   = childless_cohorte,
    "SinHijos_15_54_dpto"      = childless_dpto
  ),
  file = file.path(dir_tablas, "Fecundidad_Cohortal_Completada_IPUMS.xlsx"),
  overwrite = TRUE
)

cat("Tablas guardadas en", dir_tablas, "\n")

clean_session()
