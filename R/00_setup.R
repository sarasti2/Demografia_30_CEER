# =====================================================================
# 00_setup.R — Configuración común del proyecto
# Proyecto: Demografía CEER 30 años
#
# Se carga con source("R/00_setup.R") desde la raíz del repositorio.
# Define las rutas a los datos (ver data/README.md), el diccionario de
# departamentos y las funciones compartidas por los demás scripts.
# =====================================================================

# ---------------------------------------------------------------------
# LIBRERÍAS
# ---------------------------------------------------------------------
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")

pacman::p_load(
  dplyr,        # manipulación de datos
  tidyr,        # reestructuración de tablas
  ggplot2,      # gráficas
  viridis,      # paletas de color
  ipumsr,       # lectura de microdatos IPUMS (DDI + datos)
  readstata13,  # lectura de los .DTA del censo DANE 2018 (script auxiliar)
  readxl,       # relectura de las tablas de resultados
  arrow,        # lectura/escritura del consolidado en Parquet
  openxlsx      # exportación a Excel
)

# ---------------------------------------------------------------------
# RUTAS (relativas a la raíz del repo; los datos NO se versionan)
# ---------------------------------------------------------------------
data_dir   <- "data"
output_dir <- "output"

# IPUMS International: extracto Colombia 1973, 1985, 1993, 2005
# (descargar datos + DDI, ver data/README.md)
path_ipums_ddi   <- file.path(data_dir, "IPSUM", "ipumsi_00043.xml")
path_ipums_cache <- file.path(data_dir, "ipums_prepared.rds")

# Censo DANE 2018 (CNPV): https://microdatos.dane.gov.co/index.php/catalog/643
# Los .DTA departamentales se consolidan en Parquet con
# aux_build_cnpv2018_parquet.R; los scripts leen únicamente el Parquet.
dir_censo_2018           <- file.path(data_dir, "Censo_2018", "Raw")
path_censo_2018_parquet  <- file.path(data_dir, "Censo_2018", "CNPV2018_5PER_A2.parquet")
path_censo_2018_cache    <- file.path(data_dir, "Censo_2018",
                                      "censo2018_preparado.rds")

# Tablas de supervivencia:
#  - Departamental: {departamento}_{año}_ProbSurv_children.csv / ..._WomenProbSurv.csv
#  - Nacional:      {año}_ProbSurv_children.csv / {año}_WomenProbSurv.csv
dir_probsurv_children <- file.path(data_dir, "ProbSurv_children")
dir_probsurv_women    <- file.path(data_dir, "ProbSurv_woman")

# Años censales cubiertos por las tablas de supervivencia
census_years_all <- c(1973, 1985, 1993, 2005, 2018)

# Subcarpetas de salida. Cada carpeta de indicador tiene dentro
# departamental/ (una figura por departamento) y regional/ (una figura
# por región):
#   tablas/                       -> archivos Excel
#   graficas/resumen/             -> gráficas agregadas (nacional, paneles)
#   graficas/tfr/                 -> TFR
#   graficas/fcc/                 -> FCC
#   graficas/tfr_vs_fcc/          -> comparaciones TFR vs FCC
#   graficas/tfr_asfr_descomposicion/ -> descomposición del TFR por etapa
#   graficas/sin_hijos/           -> infecundidad definitiva por cohorte
#
# En regional/ va una figura por región, con un panel por cada
# departamento que la compone.
dir_tablas       <- file.path(output_dir, "tablas")
dir_graf         <- file.path(output_dir, "graficas")
dir_graf_resumen <- file.path(dir_graf, "resumen")

# Cada indicador tiene su carpeta, y dentro de ella una subcarpeta para
# las figuras de cada departamento y otra para las de cada región.
dir_graf_tfr_dpto <- file.path(dir_graf, "tfr", "departamental")
dir_graf_tfr_reg  <- file.path(dir_graf, "tfr", "regional")

dir_graf_fcc_dpto <- file.path(dir_graf, "fcc", "departamental")
dir_graf_fcc_reg  <- file.path(dir_graf, "fcc", "regional")

dir_graf_tfr_vs_fcc_dpto <- file.path(dir_graf, "tfr_vs_fcc", "departamental")
dir_graf_tfr_vs_fcc_reg  <- file.path(dir_graf, "tfr_vs_fcc", "regional")

dir_graf_descomposicion     <- file.path(dir_graf, "tfr_asfr_descomposicion",
                                         "departamental")
dir_graf_descomposicion_reg <- file.path(dir_graf, "tfr_asfr_descomposicion",
                                         "regional")

dir_graf_sin_hijos     <- file.path(dir_graf, "sin_hijos", "departamental")
dir_graf_sin_hijos_reg <- file.path(dir_graf, "sin_hijos", "regional")

# Nombre anterior de la carpeta de comparaciones, que algunos scripts
# todavía usan sin distinguir nivel
dir_graf_tfr_vs_fcc <- dir_graf_tfr_vs_fcc_dpto

invisible(lapply(
  c(dir_tablas, dir_graf_resumen,
    dir_graf_tfr_dpto, dir_graf_tfr_reg,
    dir_graf_fcc_dpto, dir_graf_fcc_reg,
    dir_graf_tfr_vs_fcc_dpto, dir_graf_tfr_vs_fcc_reg,
    dir_graf_descomposicion, dir_graf_descomposicion_reg,
    dir_graf_sin_hijos, dir_graf_sin_hijos_reg),
  dir.create, showWarnings = FALSE, recursive = TRUE
))

# ---------------------------------------------------------------------
# DICCIONARIO DE DEPARTAMENTOS (GEOLEV1 de IPUMS)
# Departamentos agrupados como en IPUMS:
#   Bogotá D.C. = Bogotá + Cundinamarca; Bolívar = Bolívar + Sucre;
#   Boyacá = Boyacá + Casanare; Cesar = Cesar + Norte de Santander + Magdalena;
#   Caldas = Caldas + Quindío + Risaralda;
#   Amazonas = Amazonas + Guaviare + Vaupés + Vichada + Guainía
#   (en 1993 la muestra excluye Guainía y Vaupés)
# ---------------------------------------------------------------------
department_labels <- c(
  "170005" = "Antioquia",       "170008" = "Atlántico",
  "170011" = "Bogotá D.C.",     "170013" = "Bolívar",
  "170015" = "Boyacá",          "170018" = "Caquetá",
  "170019" = "Cauca",           "170023" = "Córdoba",
  "170027" = "Chocó",           "170041" = "Huila",
  "170044" = "La Guajira",      "170050" = "Meta",
  "170052" = "Nariño",          "170054" = "Cesar",
  "170066" = "Caldas",          "170068" = "Santander",
  "170073" = "Tolima",          "170076" = "Valle del Cauca",
  "170081" = "Arauca",          "170086" = "Putumayo",
  "170088" = "San Andrés",      "170095" = "Amazonas"
)

# ---------------------------------------------------------------------
# REGIONES
# ---------------------------------------------------------------------
# Regiones naturales del DANE (Caribe, Andina, Pacífica, Orinoquía,
# Amazonía e Insular) con tres ajustes, para llegar a cinco grupos
# comparables entre sí:
#
#  1. Orinoquía y Amazonía se unen, por su baja densidad y su historia
#     de poblamiento reciente. Además, la agrupación de IPUMS ya mezcla
#     departamentos de ambas (Amazonas incluye Vichada).
#  2. San Andrés, única insular, se integra al Caribe.
#  3. La región Andina se divide en Central y Oriental, porque de otro
#     modo concentraría casi la mitad de los departamentos.
#
# Cada agrupación de IPUMS se asigna según el departamento que le da
# nombre y que aporta la mayor parte de su población.
region_de_departamento <- c(
  # Caribe (incluye la insular San Andrés)
  "Atlántico"       = "Caribe",
  "Bolívar"         = "Caribe",   # Bolívar y Sucre
  "Córdoba"         = "Caribe",
  "La Guajira"      = "Caribe",
  "Cesar"           = "Caribe",   # Cesar, Magdalena y Norte de Santander
  "San Andrés"      = "Caribe",

  # Andina central
  "Antioquia"       = "Andina central",
  "Caldas"          = "Andina central",   # Caldas, Quindío y Risaralda
  "Tolima"          = "Andina central",
  "Huila"           = "Andina central",

  # Andina oriental
  "Bogotá D.C."     = "Andina oriental",  # Bogotá y Cundinamarca
  "Boyacá"          = "Andina oriental",  # Boyacá y Casanare
  "Santander"       = "Andina oriental",

  # Pacífica
  "Chocó"           = "Pacífica",
  "Cauca"           = "Pacífica",
  "Nariño"          = "Pacífica",
  "Valle del Cauca" = "Pacífica",

  # Orinoquía y Amazonía
  "Arauca"          = "Orinoquía y Amazonía",
  "Meta"            = "Orinoquía y Amazonía",
  "Caquetá"         = "Orinoquía y Amazonía",
  "Putumayo"        = "Orinoquía y Amazonía",
  "Amazonas"        = "Orinoquía y Amazonía"  # con Guaviare, Vaupés,
                                              # Vichada y Guainía
)

regiones <- c("Caribe", "Andina central", "Andina oriental",
              "Pacífica", "Orinoquía y Amazonía")

# Añade la columna de región a partir del nombre del departamento
agregar_region <- function(df, columna = "department") {
  df %>%
    mutate(region = factor(unname(region_de_departamento[.data[[columna]]]),
                           levels = regiones))
}

# Mapeo coddpto (DIVIPOLA, censo DANE 2018) -> GEOLEV1 (agrupación IPUMS)
dane_to_geolev1 <- c(
  "5"  = "170005", "8"  = "170008",
  "11" = "170011", "25" = "170011",
  "13" = "170013", "70" = "170013",
  "15" = "170015", "85" = "170015",
  "18" = "170018", "19" = "170019", "23" = "170023", "27" = "170027",
  "41" = "170041", "44" = "170044", "50" = "170050", "52" = "170052",
  "54" = "170054", "20" = "170054", "47" = "170054",
  "66" = "170066", "17" = "170066", "63" = "170066",
  "68" = "170068", "73" = "170073", "76" = "170076",
  "81" = "170081", "86" = "170086", "88" = "170088",
  "95" = "170095", "91" = "170095", "97" = "170095",
  "99" = "170095", "94" = "170095"
)

# ---------------------------------------------------------------------
# FUNCIONES COMPARTIDAS
# ---------------------------------------------------------------------

# Lee una tabla de supervivencia y estandariza columnas a (age, probsurv),
# sin importar si el CSV trae Age/ProbSurv, age/probsurv, etc.
read_probsurv <- function(path) {
  stopifnot(file.exists(path))
  df <- read.csv(path)
  names(df) <- tolower(names(df))
  stopifnot(all(c("age", "probsurv") %in% names(df)))
  df %>%
    transmute(age = as.numeric(age), probsurv = as.numeric(probsurv))
}

# Probabilidad de supervivencia a una edad cualquiera, interpolando la
# tabla. Hace falta porque las tablas no siempre tienen las mismas
# edades que los datos: las de los censos IPUMS vienen por edad simple,
# mientras que las del censo 2018 solo traen los puntos medios de los
# grupos quinquenales. Con un cruce exacto, las edades que no coinciden
# quedarían sin probabilidad y anularían el denominador.
interpolar_probsurv <- function(tabla, edades) {
  approx(x = tabla$age, y = tabla$probsurv, xout = edades, rule = 2)$y
}

# Tablas de supervivencia de un departamento y año censal.
read_probsurv_dpto <- function(department, year) {
  list(
    child = read_probsurv(file.path(
      dir_probsurv_children,
      sprintf("%s_%s_ProbSurv_children.csv", department, year))),
    women = read_probsurv(file.path(
      dir_probsurv_women,
      sprintf("%s_%s_WomenProbSurv.csv", department, year)))
  )
}

# Lee el Censo DANE 2018 desde el Parquet consolidado.
read_censo_2018 <- function(
    cols = c("u_dpto", "cod_encuestas", "u_vivienda", "p_nrohog",
             "p_parentescor", "p_nro_per", "p_edadr", "p_sexo")) {

  if (!file.exists(path_censo_2018_parquet)) {
    stop("No se encontró ", path_censo_2018_parquet,
         ". Corre primero R/aux_build_cnpv2018_parquet.R")
  }

  cat("Leyendo Censo 2018 desde Parquet...\n")
  as.data.frame(arrow::read_parquet(path_censo_2018_parquet,
                                    col_select = all_of(cols)))
}

# Imputa el vínculo madre-hijo en el Censo 2018, que no trae MOMLOC.
# Replica las reglas de parentesco con que IPUMS construye esa variable.
# p_parentescor: 1 jefe, 2 cónyuge, 3 hijo/a, 4 nieto/a, 5 otro pariente
impute_momloc <- function(census) {

  census <- census %>% mutate(momloc = 0L)

  # Candidatas: mujeres del hogar con diferencia de edad plausible
  df_pairs <- census %>%
    inner_join(
      census %>%
        filter(p_sexo == 2) %>%
        select(household_id, mom_pernum = p_nro_per,
               mom_age = age_mid, mom_rel = p_parentescor),
      by = "household_id",
      relationship = "many-to-many"
    ) %>%
    mutate(age_diff = mom_age - age_mid) %>%
    filter(age_diff >= 10, age_diff <= 69)

  apply_rule <- function(census, rule_filter) {
    candidates <- df_pairs %>%
      filter({{ rule_filter }}) %>%
      arrange(household_id, p_nro_per, age_diff) %>%
      distinct(household_id, p_nro_per, .keep_all = TRUE) %>%
      select(household_id, p_nro_per, mom_pernum)

    census %>%
      left_join(candidates, by = c("household_id", "p_nro_per")) %>%
      mutate(momloc = if_else(momloc == 0L & !is.na(mom_pernum),
                              as.integer(mom_pernum), momloc)) %>%
      select(-mom_pernum)
  }

  # Regla 1: hijos del jefe -> jefa o cónyuge mujer
  census <- apply_rule(census, p_parentescor == 3 & mom_rel %in% c(1, 2))
  # Regla 2: nietos -> mujer del hogar con 15-44 años de diferencia
  census <- apply_rule(census,
    p_parentescor == 4 & mom_rel %in% c(1, 2) &
      age_diff >= 15 & age_diff <= 44)
  # Regla 3: otros parientes menores de 15 -> mujer con 15-50 de diferencia
  census <- apply_rule(census,
    p_parentescor == 5 & age_mid <= 15 & age_diff >= 15 & age_diff <= 50)

  census %>%
    mutate(momloc = if_else(momloc == p_nro_per, 0L, momloc))
}

# Carga el Censo 2018 listo para los cálculos de fecundidad: edad
# aproximada, departamento, vínculo madre-hijo imputado y edad de la
# madre al nacimiento. La imputación se hace por departamento (bloques
# naturales, los hogares nunca quedan partidos).
#
# Es el paso más lento del proyecto, así que el resultado se guarda en
# data/Censo_2018/censo2018_preparado.rds y los scripts 03, 04 y 06 lo
# reutilizan. Con refresh = TRUE se reconstruye.
prepare_censo_2018 <- function(refresh = FALSE) {

  if (!refresh && file.exists(path_censo_2018_cache)) {
    cat("Leyendo Censo 2018 preparado desde", path_censo_2018_cache, "\n")
    return(readRDS(path_censo_2018_cache))
  }

  preparado <- read_censo_2018() %>%
    mutate(
      household_id = paste0(cod_encuestas, u_vivienda, p_nrohog),
      # Punto medio entero del intervalo quinquenal (0-4 -> 2, 5-9 -> 7, ...)
      age_mid      = (p_edadr - 1) * 5 + 2,
      # Código de departamento sin ceros a la izquierda ("05" -> "5")
      coddpto      = as.character(as.integer(u_dpto)),
      department   = unname(department_labels[dane_to_geolev1[coddpto]])
    ) %>%
    group_split(u_dpto) %>%
    lapply(function(block) {
      cat("Imputando vínculo madre-hijo - departamento:",
          block$u_dpto[1], "\n")
      block <- impute_momloc(block)
      block %>%
        left_join(
          block %>% select(household_id, momloc = p_nro_per,
                           mom_age = age_mid),
          by = c("household_id", "momloc")
        ) %>%
        mutate(
          mother_age_at_birth = if_else(momloc != 0 & !is.na(mom_age),
                                        mom_age - age_mid, NA_real_)
        ) %>%
        select(-mom_age)
    }) %>%
    bind_rows()

  saveRDS(preparado, path_censo_2018_cache)
  cat("Censo 2018 preparado y guardado en", path_censo_2018_cache, "\n")

  preparado
}

# Carga los microdatos IPUMS listos para los cálculos: identificador de
# hogar, departamento y edad de la madre al nacimiento.
#
# El resultado se guarda en data/ipums_prepared.rds; las corridas
# siguientes lo leen de ahí. Con refresh = TRUE se reconstruye.
prepare_ipums <- function(refresh = FALSE) {

  if (!refresh && file.exists(path_ipums_cache)) {
    cat("Leyendo IPUMS preparado desde", path_ipums_cache, "\n")
    return(readRDS(path_ipums_cache))
  }

  ddi <- read_ipums_ddi(path_ipums_ddi)

  df <- read_ipums_micro(ddi) %>%
    mutate(
      across(c(YEAR, PERNUM, MOMLOC, AGE, SEX), as.numeric),
      household_id    = paste0(SAMPLE, SERIAL),
      department_code = as.character(GEOLEV1),
      department      = unname(department_labels[department_code])
    ) %>%
    select(-SAMPLE, -SERIAL) %>%
    add_mother_age_at_birth()

  saveRDS(df, path_ipums_cache)
  cat("IPUMS preparado y guardado en", path_ipums_cache, "\n")

  df
}

# Edad de la madre al nacimiento de cada hijo, vía MOMLOC (IPUMS):
# une cada persona con la fila de su madre dentro del hogar
# (PERNUM == MOMLOC) y calcula la diferencia de edades.
add_mother_age_at_birth <- function(df) {
  mothers <- df %>%
    select(household_id, MOMLOC = PERNUM, mother_age_census = AGE)
  df %>%
    left_join(mothers, by = c("household_id", "MOMLOC")) %>%
    mutate(
      mother_age_at_birth = if_else(
        MOMLOC > 0 & !is.na(mother_age_census),
        as.numeric(mother_age_census) - as.numeric(AGE),
        NA_real_
      )
    ) %>%
    select(-mother_age_census)
}

# Método de hijos propios con retro-proyección (own-children method),
# siguiendo Reid et al. (2020), https://doi.org/10.1080/00324728.2019.1630563
#
# census: individuos de UN censo (y un departamento, si aplica) con
#         columnas AGE, SEX y mother_age_at_birth.
# Devuelve filas de nacimientos ajustados por (edad del hijo, edad de la
# madre), con asfr y el año calendario del nacimiento.
compute_asfr_retrospective <- function(census,
                                       probsurv_child,
                                       probsurv_women,
                                       census_year,
                                       max_child_age = 14,
                                       mother_age_range = c(15, 50)) {

  # Proporción de niños vinculados a su madre, por edad del niño
  # (corrige el subconteo por hijos que no viven con la madre / no matched)
  prop_df <- census %>%
    filter(AGE <= max_child_age) %>%
    group_by(AGE) %>%
    summarise(
      prop = mean(!is.na(mother_age_at_birth) & mother_age_at_birth > 0),
      .groups = "drop"
    )

  # Mujeres por edad al censo
  women_by_age <- census %>%
    filter(SEX == 2) %>%
    count(AGE, name = "women")

  # Nacimientos: hijos vinculados por (edad hijo, edad madre al censo)
  births <- census %>%
    filter(
      !is.na(mother_age_at_birth),
      mother_age_at_birth >= mother_age_range[1],
      mother_age_at_birth <= mother_age_range[2],
      AGE <= max_child_age
    ) %>%
    mutate(mother_age_at_census = AGE + mother_age_at_birth) %>%
    count(AGE, mother_age_at_census, mother_age_at_birth, name = "n_child")

  births %>%
    mutate(
      prob_census = interpolar_probsurv(probsurv_women, mother_age_at_census),
      prob_birth  = interpolar_probsurv(probsurv_women, mother_age_at_birth),
      prob_child  = interpolar_probsurv(probsurv_child, AGE)
    ) %>%
    left_join(prop_df, by = "AGE") %>%
    left_join(women_by_age, by = c("mother_age_at_census" = "AGE")) %>%
    mutate(
      across(c(prop, prob_child, women),
             ~ ifelse(is.na(.x) | .x == 0, NA_real_, .x)),
      # Supervivencia de la madre entre el nacimiento y el censo
      prob_mother      = prob_census / prob_birth,
      # Ajustes por mortalidad infantil, no-matching y mortalidad materna
      n_child_adjusted = n_child / prop / prob_child,
      women_adjusted   = women / prob_mother,
      asfr             = n_child_adjusted / women_adjusted,
      # Varianza del numerador tratando los nacimientos observados como
      # Poisson: el ajuste multiplica el conteo por k, así que la
      # varianza queda k^2 * n_child = n_child_adjusted^2 / n_child
      var_child_adj    = n_child_adjusted^2 / n_child,
      year             = census_year - 1 - AGE,   # año calendario del nacimiento
      census_year      = census_year
    )
}

# Agrega las filas de compute_asfr_retrospective() a ASFR y TFR.
#
# group_vars: character(0) para nacional, "department" para deptos.
#
# Los nacimientos y las mujeres ajustados se suman sobre todos los
# censos que cubren cada año calendario, de modo que la serie tiene un
# único valor por año (no uno por censo). Con by_census = TRUE se
# conserva la desagregación por censo, útil para comparar los tramos
# que se solapan.
#
# Intervalos de confianza: los nacimientos observados se tratan como
# Poisson y las mujeres como fijas, así que
#   Var(asfr_m) = Var(nacimientos ajustados_m) / mujeres_m^2
#   Var(TFR)    = suma de Var(asfr_m) sobre las edades de la madre.
# Es una aproximación: ignora el conglomerado por hogar y la
# incertidumbre de las tablas de supervivencia y del ajuste por hijos
# no vinculados, así que subestima el error real.
aggregate_asfr_tfr <- function(asfr_rows, group_vars = character(0),
                               by_census = FALSE, conf_level = 0.95) {

  vars_year <- if (by_census) c("year", "census_year") else "year"
  z <- qnorm(1 - (1 - conf_level) / 2)

  asfr <- asfr_rows %>%
    group_by(across(all_of(c(group_vars, vars_year, "mother_age_at_birth")))) %>%
    summarise(
      total_women = sum(women_adjusted,   na.rm = TRUE),
      total_child = sum(n_child_adjusted, na.rm = TRUE),
      var_child   = sum(var_child_adj,    na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      asfr     = total_child / total_women,
      var_asfr = var_child / total_women^2,
      se_asfr  = sqrt(var_asfr)
    )

  tfr <- asfr %>%
    group_by(across(all_of(c(group_vars, vars_year)))) %>%
    summarise(
      tfr    = sum(asfr, na.rm = TRUE),
      se_tfr = sqrt(sum(var_asfr, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    mutate(
      tfr_lower = tfr - z * se_tfr,
      tfr_upper = tfr + z * se_tfr
    ) %>%
    filter(is.finite(tfr), tfr > 0)

  list(asfr = asfr, tfr = tfr)
}

# ---------------------------------------------------------------------
# ESTILO DE GRÁFICAS
# ---------------------------------------------------------------------
# Convenciones del proyecto:
#   - serie nacional: línea negra punteada
#   - rango departamental: banda gris con borde
#   - departamentos destacados: colores fuertes
#   - leyenda abajo, sin título; eje de años cada cinco
theme_fecundidad <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      # Título centrado y en negrilla
      plot.title       = element_text(face = "bold", hjust = 0.5),
      plot.subtitle    = element_text(color = "grey30", hjust = 0.5),
      plot.title.position = "plot",
      plot.caption     = element_text(color = "grey30", hjust = 0,
                                      size = rel(0.75),
                                      margin = margin(t = 6)),
      plot.caption.position = "plot",
      legend.position  = "bottom",
      # Cuando hay dos leyendas (las categorías y el nivel de reemplazo)
      # se apilan una sobre otra en vez de ponerse lado a lado
      legend.box       = "vertical",
      legend.box.spacing = unit(0.3, "lines"),
      legend.margin    = margin(t = 0, b = 0),
      legend.title     = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey92", linewidth = 0.3),

      # Cada panel queda enmarcado y separado del vecino, con el nombre
      # del departamento sobre una franja gris
      panel.border     = element_rect(color = "grey40", fill = NA,
                                      linewidth = 0.5),
      panel.spacing    = unit(0.6, "lines"),
      strip.background = element_rect(fill = "grey90", color = "grey40",
                                      linewidth = 0.5),
      strip.text       = element_text(face = "bold", color = "grey20",
                                      margin = margin(4, 4, 4, 4))
    )
}

col_nacional   <- "black"
col_banda_fill <- "grey85"
col_banda_line <- "grey50"

# Comparaciones de dos series: departamento en azul, total nacional en rojo
col_dpto  <- "#4C7FB8"
col_total <- "#D42A2A"
col_destacados <- c("#1F78B4", "#33A02C", "#E31A1C", "#FF7F00",
                    "#6A3D9A", "#B15928", "#A6CEE3", "#B2DF8A")

# Etapas reproductivas. La paleta fuerte es para las figuras que solo
# muestran la descomposición; la pastel es para las de TFR, donde el
# área es el fondo y lo que debe resaltar es la línea nacional encima.
col_etapas <- c("Adolescente (15-19)"    = "#F0A202",
                "Edad central (20-34)"   = "#1F78B4",
                "Edad avanzada (35-39)"  = "#33A02C",
                "Edad tardía (40 y más)" = "#B15928")

col_etapas_pastel <- c("Adolescente (15-19)"    = "#FBE2AC",
                       "Edad central (20-34)"   = "#C3DBEF",
                       "Edad avanzada (35-39)"  = "#CBE8C4",
                       "Edad tardía (40 y más)" = "#E6D2BE")

# Devuelve n colores de la paleta; si se piden más de los definidos,
# los interpola.
col_series <- function(n) {
  if (n <= length(col_destacados)) {
    col_destacados[seq_len(n)]
  } else {
    colorRampPalette(col_destacados)(n)
  }
}

escala_anios <- function(by = 5) {
  scale_x_continuous(breaks = seq(1955, 2020, by = by))
}

# Nivel de reemplazo generacional: 2,1 hijos por mujer
tasa_reemplazo <- 2.1

# ---------------------------------------------------------------------
# HITOS DE POLÍTICA DE PLANIFICACIÓN FAMILIAR
# ---------------------------------------------------------------------
# Profamilia se funda en 1965. Se marca como referencia en las figuras
# de años calendario.
anio_profamilia <- 1965

# En las figuras por cohorte la referencia es la cohorte de 1930: cumple
# 35 años en 1965, con la vida fértil casi terminada, así que queda poco
# expuesta a estas medidas. Las cohortes posteriores lo están cada vez
# más.
cohorte_referencia <- 1930

col_marca <- "grey35"

pie_planificacion <- paste(
  "Línea vertical:", anio_profamilia, "- creación de Profamilia."
)

pie_cohorte <- paste(
  "Línea vertical: cohorte de", cohorte_referencia,
  "- cumple 35 años en", anio_profamilia,
  "y es la última poco expuesta a la planificación familiar."
)

# Marcas para las figuras en años calendario (TFR, descomposición)
marcas_planificacion <- function(pie = TRUE) {
  capas <- list(
    geom_vline(xintercept = anio_profamilia, color = col_marca,
               linetype = "dotted", linewidth = 0.5)
  )
  if (pie) capas <- c(capas, list(labs(caption = pie_planificacion)))
  capas
}

# Marca para las figuras por cohorte de nacimiento (FCC)
marca_cohorte <- function(pie = TRUE) {
  capas <- list(
    geom_vline(xintercept = cohorte_referencia, color = col_marca,
               linetype = "dotted", linewidth = 0.5)
  )
  if (pie) capas <- c(capas, list(labs(caption = pie_cohorte)))
  capas
}

# Media móvil centrada. Sirve para leer la tendencia de series que
# saltan por el tamaño de muestra, como el porcentaje de mujeres sin
# hijos en cohortes con pocas observaciones.
media_movil <- function(x, ventana = 5) {
  n <- length(x)
  medio <- (ventana - 1) %/% 2
  vapply(seq_len(n), function(i) {
    idx <- max(1, i - medio):min(n, i + medio)
    mean(x[idx], na.rm = TRUE)
  }, numeric(1))
}

# Eje vertical común a todas las figuras departamentales, para que sean
# comparables entre sí, con el nivel de reemplazo marcado en la leyenda
# Se usa coord_cartesian en lugar de scale_y_continuous(limits = ...)
# porque este último descarta las filas fuera de rango: con áreas
# apiladas eso puede vaciar un panel y romper el dibujo.
# coord_cartesian solo recorta la vista.
escala_fecundidad <- function(limites = c(0, 12), by = 2) {
  etiqueta <- "Nivel de reemplazo (2,1)"
  list(
    geom_hline(data = data.frame(y = tasa_reemplazo),
               aes(yintercept = y, linetype = etiqueta),
               color = col_banda_line, linewidth = 0.5,
               inherit.aes = FALSE),
    scale_linetype_manual(name = NULL,
                          values = setNames("dotted", etiqueta)),
    scale_y_continuous(breaks = seq(limites[1], limites[2], by = by)),
    coord_cartesian(ylim = limites)
  )
}

# Leyenda de las áreas apiladas: las categorías en una fila y el nivel
# de reemplazo en otra, debajo.
leyenda_dos_filas <- function() {
  guides(
    fill     = guide_legend(nrow = 1, order = 1),
    linetype = guide_legend(nrow = 1, order = 2)
  )
}

# Recorre las cinco regiones y llama a `dibujar` con los datos de los
# departamentos de cada una. Cada región produce una sola figura, con un
# panel por departamento.
por_region <- function(datos, dibujar, columna = "department") {

  if (is.null(datos) || nrow(datos) == 0) return(invisible(NULL))

  datos <- agregar_region(datos, columna)

  faltan <- datos %>% filter(is.na(region)) %>% distinct(.data[[columna]])
  if (nrow(faltan) > 0) {
    warning("Sin región asignada: ",
            paste(faltan[[columna]], collapse = ", "))
  }

  for (reg in regiones) {
    datos_reg <- datos %>% filter(region == reg)
    if (nrow(datos_reg) == 0) next
    dibujar(datos_reg, reg, gsub(" ", "_", reg))
  }
}

# ---------------------------------------------------------------------
# LIMPIEZA DE MEMORIA
# ---------------------------------------------------------------------
# Borra del entorno global todo lo que no venga de este archivo y libera
# la memoria. Los scripts la llaman al terminar, para que los microdatos
# no queden cargados al pasar al siguiente.
clean_session <- function(verbose = TRUE) {

  extras <- setdiff(ls(envir = .GlobalEnv), setup_objects)

  if (length(extras) > 0) {
    rm(list = extras, envir = .GlobalEnv)
    if (verbose) {
      cat("Objetos liberados:", length(extras), "\n")
    }
  }

  invisible(gc(verbose = FALSE))
}

# Nombres presentes al terminar el setup: son los que clean_session()
# conserva.
setup_objects <- c(ls(envir = .GlobalEnv), "setup_objects")
