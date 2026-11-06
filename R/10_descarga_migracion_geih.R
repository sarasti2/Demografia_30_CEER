# =====================================================================
# 10_descarga_migracion_geih.R — Descarga de microdatos de migración GEIH
# Proyecto: Demografía CEER 30 años
#
# Descarga los ZIP que usa R/11_flujos_migracion_geih.R:
#
#   2012 y 2019  Módulo de Migración GEIH (catálogos DANE 634 y 641), un
#                ZIP por mes. El departamento de residencia no viene en
#                el módulo; 11 lo toma de los ZIP del Empalme, que se
#                descargan a mano en data/GEIH_migracion/raw/empalme/
#                (GEIH_Empalme_{año}.zip, ver data/README.md).
#   2022 y 2024  GEIH marco 2018 completa (catálogos 771 y 819), un ZIP por
#                mes (~65 MB) con Migración.CSV y Características
#                generales. Son los mismos enlaces del registro de pulso.
#
# Los archivos que ya existen y abren como ZIP válido no se vuelven a
# descargar, así que el script se puede correr de nuevo si se corta.
#
# Salida: data/GEIH_migracion/raw/{modulo_2012, modulo_2019, geih_2022,
#         geih_2024}/MM_Mes.zip
# =====================================================================

if (!exists("data_dir")) source("R/00_setup.R")

dir_mig_raw <- file.path(data_dir, "GEIH_migracion", "raw")

MESES <- c("Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
           "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre")

# Identificador de descarga por mes (páginas "Obtener Microdatos" del
# DANE). El módulo de 2012 no tiene enero.
fuentes_mig <- list(
  modulo_2012 = list(catalogo = 634, ids = c(
    `2` = 11874, `3` = 11875, `4` = 11876, `5` = 11877, `6` = 11878,
    `7` = 11879, `8` = 11880, `9` = 11881, `10` = 11882, `11` = 11883,
    `12` = 11884)),
  modulo_2019 = list(catalogo = 641, ids = c(
    `1` = 12062, `2` = 12063, `3` = 12064, `4` = 12065, `5` = 12066,
    `6` = 12067, `7` = 12104, `8` = 12176, `9` = 12288, `10` = 12320,
    `11` = 12477, `12` = 12511)),
  geih_2022 = list(catalogo = 771, ids = c(
    `1` = 22688, `2` = 22689, `3` = 22690, `4` = 22894, `5` = 22692,
    `6` = 22693, `7` = 22694, `8` = 22695, `9` = 22696, `10` = 22697,
    `11` = 23016, `12` = 22699)),
  geih_2024 = list(catalogo = 819, ids = c(
    `1` = 23313, `2` = 23362, `3` = 23596, `4` = 23496, `5` = 23598,
    `6` = 23625, `7` = 23631, `8` = 23651, `9` = 23671, `10` = 23677,
    `11` = 23729, `12` = 23794))
)

zip_valido <- function(f) {
  file.exists(f) && !inherits(try(unzip(f, list = TRUE), silent = TRUE), "try-error")
}

options(timeout = max(3600, getOption("timeout")))

fallidos <- character()
for (carpeta in names(fuentes_mig)) {
  fuente <- fuentes_mig[[carpeta]]
  dir.create(file.path(dir_mig_raw, carpeta), showWarnings = FALSE,
             recursive = TRUE)
  cat("\n===", carpeta, "===\n")

  for (mes in names(fuente$ids)) {
    m <- as.integer(mes)
    destino <- file.path(dir_mig_raw, carpeta,
                         sprintf("%02d_%s.zip", m, MESES[m]))
    if (zip_valido(destino)) {
      cat(sprintf("  %02d: ya existe, se omite\n", m))
      next
    }
    url <- sprintf("https://microdatos.dane.gov.co/index.php/catalog/%d/download/%d",
                   fuente$catalogo, fuente$ids[[mes]])
    ok <- FALSE
    for (intento in 1:3) {
      res <- try(download.file(url, destino, mode = "wb", quiet = TRUE),
                 silent = TRUE)
      if (!inherits(res, "try-error") && zip_valido(destino)) {
        cat(sprintf("  %02d: %.1f MB\n", m, file.size(destino) / 1e6))
        ok <- TRUE
        break
      }
      cat(sprintf("  %02d: intento %d falló\n", m, intento))
      Sys.sleep(5)
    }
    if (!ok) {
      unlink(destino)
      fallidos <- c(fallidos, paste(carpeta, m, url))
    }
  }
}

if (length(fallidos) > 0) {
  cat("\nNo se pudieron descargar:\n", paste0(" - ", fallidos, "\n"), sep = "")
} else {
  cat("\nDescarga completa en", dir_mig_raw, "\n")
}
