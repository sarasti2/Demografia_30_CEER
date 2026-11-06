# =====================================================================
# run_all.R — Corre todo el proyecto en orden
#
# Desde la raíz del repositorio:
#   source("run_all.R")
# o desde la terminal:
#   Rscript run_all.R
#
# Requiere que los datos estén descargados (ver data/README.md).
# Cada script libera la memoria al terminar, así que se pueden correr
# todos seguidos.
# =====================================================================

t_inicio <- Sys.time()

# El consolidado del Censo 2018 se genera una sola vez; si ya existe se
# omite, porque tarda varios minutos
source("R/00_setup.R")
correr_parquet <- !file.exists(path_censo_2018_parquet)

scripts <- c(
  if (correr_parquet) "R/aux_build_cnpv2018_parquet.R",
  "R/01_asfr_tfr_nacional_ipums.R",
  "R/02_asfr_tfr_departamental_ipums.R",
  "R/03_asfr_tfr_nacional_2018.R",
  "R/04_asfr_tfr_departamental_2018.R",
  "R/05_fcc_ipums.R",
  "R/06_fcc_2018_dane.R",
  "R/07_densidad_fecundidad.R",
  "R/08_indicadores_asfr.R",
  "R/09_figuras_tfr_fcc.R",
  # Migración interna (GEIH). 10 solo descarga lo que falte.
  "R/10_descarga_migracion_geih.R",
  "R/11_flujos_migracion_geih.R",
  "R/12_figuras_migracion_chord.R"
)

if (!correr_parquet) {
  cat("El Parquet del Censo 2018 ya existe; se omite el paso de consolidación.\n")
}

resultados <- data.frame(
  script   = character(),
  estado   = character(),
  minutos  = numeric(),
  mensaje  = character(),
  stringsAsFactors = FALSE
)

for (s in scripts) {

  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("Corriendo: ", s, "\n", sep = "")
  cat(strrep("=", 70), "\n\n", sep = "")

  t0 <- Sys.time()

  estado  <- "ok"
  mensaje <- ""

  tryCatch(
    source(s, echo = FALSE),
    error = function(e) {
      estado  <<- "ERROR"
      mensaje <<- conditionMessage(e)
      cat("\n*** ERROR en ", s, ": ", conditionMessage(e), "\n", sep = "")
    }
  )

  minutos <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

  resultados <- rbind(
    resultados,
    data.frame(script = s, estado = estado,
               minutos = round(minutos, 1), mensaje = mensaje,
               stringsAsFactors = FALSE)
  )

  # clean_session() se pierde al fallar un script, así que se repone
  source("R/00_setup.R")
}

# ---------------------------------------------------------------------
# RESUMEN
# ---------------------------------------------------------------------
cat("\n", strrep("=", 70), "\n", sep = "")
cat("RESUMEN\n")
cat(strrep("=", 70), "\n", sep = "")
print(resultados[, c("script", "estado", "minutos")], row.names = FALSE)

fallidos <- resultados[resultados$estado == "ERROR", ]
if (nrow(fallidos) > 0) {
  cat("\nScripts con error:\n")
  for (i in seq_len(nrow(fallidos))) {
    cat(" - ", fallidos$script[i], ": ", fallidos$mensaje[i], "\n", sep = "")
  }
} else {
  cat("\nTodos los scripts corrieron sin errores.\n")
}

cat(sprintf("\nTiempo total: %.1f minutos\n",
            as.numeric(difftime(Sys.time(), t_inicio, units = "mins"))))
cat("Resultados en output/tablas/ y output/graficas/ (migración en sus subcarpetas migracion/)\n")
