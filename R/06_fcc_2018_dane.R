# =====================================================================
# 06_fcc_2018_dane.R — Fecundidad Cohortal Completada (FCC), Censo 2018
#
# Censo DANE 2018 (CNPV). Mujeres 50-60 (edad quinquenal media) =
# fecundidad completada.
#
# El número de hijos se arma con dos variables: pa_hnv indica si la
# mujer ha tenido hijos nacidos vivos y pa1_thnv el total, que solo se
# registra a quienes responden que sí. Las que declaran no haber tenido
# cuentan como cero; solo se excluye a quienes no informan.
# Incluye también el % de mujeres sin hijos (15-54).
# =====================================================================

source("R/00_setup.R")

YEAR_CENSUS <- 2018

# ---------------------------------------------------------------------
# CARGAR CENSO DANE 2018
# ---------------------------------------------------------------------
fulldata <- read_censo_2018(
  cols = c("u_dpto", "cod_encuestas", "u_vivienda", "p_nrohog",
           "p_nro_per", "p_edadr", "p_sexo", "pa_hnv", "pa1_thnv",
           "p_est_civil")
) %>%
  mutate(
    age_mid    = (p_edadr - 1) * 5 + 2,
    coddpto    = as.character(as.integer(u_dpto)),
    department = unname(department_labels[dane_to_geolev1[coddpto]])
  )

# ---------------------------------------------------------------------
# 1. BASE FCC: mujeres 50-60 con información de fecundidad
# ---------------------------------------------------------------------
# El censo pregunta primero si la mujer ha tenido hijos nacidos vivos
# (pa_hnv) y solo a quienes responden que sí les registra el total
# (pa1_thnv). Las que nunca tuvieron hijos quedan con pa1_thnv vacío:
# si se excluyeran por ese vacío se estaría eliminando justamente a las
# mujeres sin hijos, lo que subiría la FCC y anularía la infecundidad.
women_all <- fulldata %>%
  filter(p_sexo == 2, age_mid >= 50, age_mid <= 60)

fcc_base <- women_all %>%
  mutate(
    hijos = case_when(
      pa_hnv == 2                          ~ 0,          # declara no haber tenido
      pa_hnv == 1 & !pa1_thnv %in% c(98, 99) ~ pa1_thnv,  # total declarado
      TRUE                                 ~ NA_real_    # sin dato
    ),
    # "Alguna vez casada o unida": todo estado civil que no sea soltera.
    # p_est_civil (CNPV 2018): 1-2 union libre, 3 casada, 4 separada,
    # 5 divorciada, 6 viuda, 7 soltera, 9 no informa. Se toman 1-6; el
    # resto queda fuera del subgrupo (pero sigue contando en el total).
    ever_partnered = p_est_civil %in% c(1, 2, 3, 4, 5, 6)
  ) %>%
  filter(!is.na(hijos)) %>%
  mutate(cohort = YEAR_CENSUS - age_mid)

sin_dato <- nrow(women_all) - nrow(fcc_base)
sin_hijos <- sum(fcc_base$hijos == 0)

cat(sprintf(
  paste("Mujeres 50-60: %d | sin información de fecundidad: %d (%.1f%%)\n",
        "  de las incluidas, nunca tuvieron hijos: %d (%.1f%%)\n"),
  nrow(women_all), sin_dato, 100 * sin_dato / nrow(women_all),
  sin_hijos, 100 * sin_hijos / nrow(fcc_base)
))

# ---------------------------------------------------------------------
# 2. FCC (total y condicional a ser madre)
# ---------------------------------------------------------------------
compute_fcc <- function(base, group_vars) {
  fcc_all <- base %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      women          = n(),
      total_children = sum(hijos),
      fcc_all        = total_children / women,
      # mujeres alguna vez casadas o unidas (para la infecundidad de casadas)
      women_cas      = sum(ever_partnered),
      .groups = "drop"
    )

  fcc_cond <- base %>%
    filter(hijos >= 1) %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      mothers     = n(),
      fcc_cond    = sum(hijos) / mothers,
      # madres alguna vez casadas o unidas
      mothers_cas = sum(ever_partnered),
      .groups = "drop"
    )

  left_join(fcc_all, fcc_cond, by = group_vars)
}

FCC_2018          <- compute_fcc(fcc_base, c("department", "cohort"))
FCC_2018_NACIONAL <- compute_fcc(fcc_base, "cohort")

# ---------------------------------------------------------------------
# 3. % DE MUJERES SIN HIJOS, 15-54
# ---------------------------------------------------------------------
# Mismo criterio que arriba: quienes declaran no haber tenido hijos
# cuentan como cero, no como dato faltante
childless_base <- fulldata %>%
  filter(p_sexo == 2, age_mid >= 15, age_mid <= 54) %>%
  mutate(
    hijos = case_when(
      pa_hnv == 2                            ~ 0,
      pa_hnv == 1 & !pa1_thnv %in% c(98, 99) ~ pa1_thnv,
      TRUE                                   ~ NA_real_
    )
  ) %>%
  filter(!is.na(hijos))

childless <- childless_base %>%
  group_by(age_mid) %>%
  summarise(
    women         = n(),
    pct_childless = 100 * mean(hijos == 0),
    .groups = "drop"
  )

childless_dpto <- childless_base %>%
  filter(!is.na(department)) %>%
  group_by(department) %>%
  summarise(
    women         = n(),
    pct_childless = 100 * mean(hijos == 0),
    .groups = "drop"
  )

# Los microdatos ya no se necesitan
rm(fulldata, women_all, fcc_base, childless_base); gc(verbose = FALSE)

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

clean_session()
