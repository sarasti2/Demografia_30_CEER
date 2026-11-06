# =====================================================================
# aux_build_cnpv2018_parquet.R — (AUXILIAR) Consolidar el Censo 2018
#
# El CNPV 2018 se descarga del DANE como un archivo .DTA por
# departamento (data/Censo_2018/Raw/CNPV2018_5PER_A2_XX.DTA, ~17 GB en
# total). Este script los une en un solo archivo, quedándose solo con
# las columnas que usa el proyecto, y lo guarda en formato Parquet.
#
# Correrlo una vez antes que los scripts 03, 04 y 06, que leen el
# Parquet resultante.
#
# Salida: data/CNPV2018_5PER_A2.parquet
# =====================================================================

source("R/00_setup.R")

# Columnas necesarias para el proyecto:
#   u_dpto          código de departamento (DIVIPOLA)
#   cod_encuestas   \
#   u_vivienda       > identificación del hogar
#   p_nrohog        /
#   p_nro_per       número de persona dentro del hogar
#   p_parentescor   parentesco con el jefe de hogar
#   p_edadr         edad en grupos quinquenales (1 = 0-4, 2 = 5-9, ...)
#   p_sexo          1 hombre, 2 mujer
#   pa_hnv          ¿ha tenido hijos nacidos vivos? (1 sí, 2 no, 9 sin dato)
#   pa1_thnv        total de hijos nacidos vivos (vacío si pa_hnv no es 1)
#   p_est_civil     estado civil (1-2 unión libre, 3 casada, 4 separada,
#                   5 divorciada, 6 viuda, 7 soltera, 9 no informa)
cols_censo <- c(
  "u_dpto", "cod_encuestas", "u_vivienda", "p_nrohog",
  "p_parentescor", "p_nro_per", "p_edadr", "p_sexo",
  "pa_hnv", "pa1_thnv", "p_est_civil"
)

archivos <- list.files(
  dir_censo_2018,
  pattern = "^CNPV2018_5PER_A2_[0-9]+\\.DTA$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(archivos) == 0) {
  stop("No se encontraron archivos CNPV2018_5PER_A2_XX.DTA en ", dir_censo_2018)
}

cat(sprintf("Archivos departamentales encontrados: %d\n", length(archivos)))

# Reporta departamentos faltantes frente a la lista DIVIPOLA completa
dptos_encontrados <- sub(".*_A2_([0-9]+)\\.DTA$", "\\1",
                         basename(archivos), ignore.case = TRUE)
dptos_esperados <- c("05","08","11","13","15","17","18","19","20","23","25",
                     "27","41","44","47","50","52","54","63","66","68","70",
                     "73","76","81","85","86","88","91","94","95","97","99")
faltantes <- setdiff(dptos_esperados, dptos_encontrados)
if (length(faltantes) > 0) {
  warning("Faltan los departamentos: ", paste(faltantes, collapse = ", "),
          ". Descárgalos del DANE antes de generar el archivo consolidado.")
} else {
  cat("Los 33 departamentos están completos.\n")
}

# ---------------------------------------------------------------------
# LECTURA Y CONSOLIDACIÓN
# ---------------------------------------------------------------------
censo <- vector("list", length(archivos))

for (i in seq_along(archivos)) {

  cat(sprintf("[%2d/%2d] %s ... ", i, length(archivos), basename(archivos[i])))

  bloque <- read.dta13(
    archivos[i],
    select.cols     = cols_censo,
    convert.factors = FALSE
  )

  # Tipos homogéneos entre departamentos
  bloque$u_dpto        <- as.character(bloque$u_dpto)
  bloque$cod_encuestas <- as.character(bloque$cod_encuestas)
  bloque$u_vivienda    <- as.character(bloque$u_vivienda)
  bloque$p_nrohog      <- as.integer(bloque$p_nrohog)
  bloque$p_nro_per     <- as.integer(bloque$p_nro_per)
  bloque$p_est_civil   <- as.integer(bloque$p_est_civil)

  censo[[i]] <- bloque
  cat(sprintf("%s filas\n", format(nrow(bloque), big.mark = ".")))
}

censo <- bind_rows(censo)

cat(sprintf("\nTotal consolidado: %s personas, %d departamentos\n",
            format(nrow(censo), big.mark = "."),
            length(unique(censo$u_dpto))))

# ---------------------------------------------------------------------
# ESCRITURA EN PARQUET
# ---------------------------------------------------------------------
write_parquet(censo, path_censo_2018_parquet, compression = "snappy")

cat(sprintf("Archivo generado: %s (%.0f MB)\n",
            path_censo_2018_parquet,
            file.size(path_censo_2018_parquet) / 1024^2))

clean_session()



