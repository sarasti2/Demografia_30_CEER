# =====================================================================
# 11_flujos_migracion_geih.R — Flujos de migración interna (GEIH)
# Proyecto: Demografía CEER 30 años
#
# Replica los flujos interdepartamentales de Acosta y Gu (2022, DTSERU
# 304) para 2012 y 2019 y los extiende a 2022 y 2024 (GEIH marco 2018). Requiere correr
# antes R/10_descarga_migracion_geih.R.
#
# Definiciones (una persona es migrante si su departamento de
# residencia actual difiere del de referencia):
#
#   Migrante a 5 años
#     2012: P6074 = 2 (no siempre ha vivido en el municipio),
#           P6075 <= 5 (llegó hace 5 años o menos), P6076 = 2 (antes vivía
#           en otro municipio de Colombia); origen = P6076S1.
#           2012 no pregunta dónde vivía hace 5 años: como en el
#           documento, el pool se recupera de los años en el municipio.
#     2019: P755 = 3 (hace 5 años vivía en otro municipio); origen = P755S1.
#     2022, 2024: P3382 = 3; origen = P3382S1.
#   Migrante a 1 año
#     2012: P6075 = 1 y P6076 = 2; origen = P6076S1.
#     2019: P753 = 3; origen = P753S1.
#     2022, 2024: P3384 = 3; origen = P3384S1.
#
# Destino = departamento donde se hace la encuesta (DPTO). En 2012 y 2019
# el módulo de migración no trae DPTO: se toma de Características
# generales del Empalme (data/GEIH_migracion/raw/empalme/, se descarga a
# mano, ver data/README.md), uniendo por
# DIRECTORIO, SECUENCIA_P, ORDEN y mes.
#
# Universo: los 24 departamentos donde la GEIH es representativa en todo
# el período (23 + Bogotá), en sistema cerrado, como en el documento.
#
# Valor anual = promedio mensual de la población expandida, en miles
# ("val"). Factores de expansión:
#   - fex_c_2011 (proyecciones CNPV 2005): el del documento, se usa para
#     replicar 2012 y 2019.
#   - FEX_C del Empalme (2012, 2019) y FEX_C18 (2022, 2024), todos con
#     base en el CNPV 2018: son los comparables entre los cuatro años.
#
# Salidas en output/tablas/migracion/:
#   flows_5y_{año}.csv, flows_1y_{año}.csv   formato de flows_5y_2019.csv
#                                             (factor CNPV 2018)
#   flows_5y_{año}_fex2011.csv               réplica con fex_c_2011
#   flujos_migracion_geih.xlsx               todo en formato largo, tasas
#                                             por departamento y réplica
# =====================================================================

if (!exists("data_dir")) source("R/00_setup.R")

pacman_ok <- requireNamespace("pacman", quietly = TRUE)
if (pacman_ok) pacman::p_load(data.table, openxlsx) else {
  library(data.table); library(openxlsx)
}

# ---------------------------------------------------------------------
# RUTAS Y PARÁMETROS
# ---------------------------------------------------------------------
dir_mig_raw   <- file.path(data_dir, "GEIH_migracion", "raw")
dir_mig_int   <- file.path(data_dir, "GEIH_migracion", "intermedio")
dir_mig_ref   <- file.path(data_dir, "GEIH_migracion", "referencia")
dir_empalme   <- file.path(dir_mig_raw, "empalme")         # ZIPs del Empalme
dir_tab_mig   <- file.path(output_dir, "tablas", "migracion")
invisible(lapply(c(dir_mig_int, dir_tab_mig), dir.create,
                 showWarnings = FALSE, recursive = TRUE))

# Flujos originales de Acosta y Gu (2019, 5 años) para comparar la réplica
path_ref_2019 <- file.path(dir_mig_ref, "flows_5y_2019_AcostaGu.csv")

# Años de la extensión (GEIH marco 2018)
anios_ext <- c(2022, 2024)

MESES <- c("Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
           "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre")

# 24 departamentos del documento, con las etiquetas cortas de
# flows_5y_2019.csv (las usa el diagrama de cuerdas) y su región
dptos_mig <- data.table(
  cod = c(5, 8, 11, 13, 15, 17, 18, 19, 20, 23, 25, 27,
          41, 44, 47, 50, 52, 54, 63, 66, 68, 70, 73, 76),
  corto = c("Antioquia", "Atlantico", "Bogota", "Bolivar", "Boyaca",
            "Caldas", "Caque", "Cauca", "Cesar", "Cordoba", "Cundinamarca",
            "Choco", "Huila", "Guaj", "Magd", "Meta", "Narino", "NS",
            "Quind", "Risaral", "Santand", "Sucre", "Tolima", "Valle"),
  nombre = c("Antioquia", "Atlántico", "Bogotá D.C.", "Bolívar", "Boyacá",
             "Caldas", "Caquetá", "Cauca", "Cesar", "Córdoba",
             "Cundinamarca", "Chocó", "Huila", "La Guajira", "Magdalena",
             "Meta", "Nariño", "Norte de Santander", "Quindío", "Risaralda",
             "Santander", "Sucre", "Tolima", "Valle del Cauca"),
  # Regiones de 00_setup.R, a nivel de departamento DANE. Norte de
  # Santander va con Andina oriental (en IPUMS se agrupa con Cesar).
  region = c("Andina central", "Caribe", "Andina oriental", "Caribe",
             "Andina oriental", "Andina central", "Orinoquía y Amazonía",
             "Pacífica", "Caribe", "Caribe", "Andina oriental", "Pacífica",
             "Andina central", "Caribe", "Caribe", "Orinoquía y Amazonía",
             "Pacífica", "Andina oriental", "Andina central",
             "Andina central", "Andina oriental", "Caribe",
             "Andina central", "Pacífica")
)

# ---------------------------------------------------------------------
# FUNCIONES DE LECTURA
# ---------------------------------------------------------------------

# Nombres en mayúscula y llaves numéricas
normalizar <- function(dt) {
  setnames(dt, toupper(names(dt)))
  for (v in intersect(c("DIRECTORIO", "SECUENCIA_P", "ORDEN", "HOGAR", "MES",
                        "DPTO"), names(dt))) {
    set(dt, j = v, value = as.integer(as.character(dt[[v]])))
  }
  dt
}

# Lee un archivo del DANE (CSV con separador ; o , o DTA)
leer_archivo <- function(path) {
  if (grepl("\\.dta$", path, ignore.case = TRUE)) {
    dt <- as.data.table(haven::read_dta(path))
    dt[] <- lapply(dt, function(x) if (inherits(x, "haven_labelled")) as.vector(x) else x)
  } else {
    dt <- fread(path, colClasses = "character", encoding = "Latin-1",
                showProgress = FALSE)
  }
  normalizar(dt)
}

# Extrae de un ZIP el primer archivo de datos cuyo nombre cumple `patron`
# (expresión regular) y devuelve su ruta, renombrado a un nombre ASCII.
#
# Los ZIP del DANE traen nombres con tildes en codificaciones distintas
# ("Caracterбsticas", "Caracter¡sticas", "Caracter#U00edsticas"). En
# Windows, unzip() de R puede fallar con esos nombres ("invalid multibyte
# string"), tanto al listar como al extraer. Por eso:
#   1. se intenta con unzip() de R, buscando el nombre por bytes;
#   2. si falla, se extraen con el tar de Windows (C:\Windows\System32\
#      tar.exe, que abre ZIP) solo las carpetas CSV, y el archivo se busca
#      en disco. En Linux/Mac se usa bsdtar o unzip del sistema.
# Algunos meses traen los CSV dentro de otro ZIP (CSV.zip, "CSV 4.zip"):
# en ese caso se extrae ese ZIP interno y se busca adentro.
extraer_de_zip <- function(zip_path, patron, exdir) {
  es <- function(p, x) grepl(p, x, ignore.case = TRUE, useBytes = TRUE)
  es_datos <- function(x) es("\\.(csv|dta|txt)$", x)
  preferir_csv <- function(x) x[order(!es("\\.csv$", x))]
  sub_dir <- tempfile("x", tmpdir = exdir); dir.create(sub_dir)
  on.exit(unlink(sub_dir, recursive = TRUE), add = TRUE)

  terminar <- function(f) {
    destino <- file.path(exdir, paste0("extraido_", basename(tempfile("")), ".",
                                       tolower(sub(".*\\.", "", f, useBytes = TRUE))))
    if (!file.rename(f, destino)) file.copy(f, destino)
    destino
  }

  # 1. unzip() de R
  nm <- tryCatch(unzip(zip_path, list = TRUE)$Name, error = function(e) NULL)
  if (!is.null(nm)) {
    cand <- preferir_csv(nm[es(patron, nm) & es_datos(nm)])
    if (length(cand) > 0) {
      out <- tryCatch(suppressWarnings(
        unzip(zip_path, files = cand[1], exdir = sub_dir, junkpaths = TRUE)),
        error = function(e) character(0))
      if (length(out) > 0 && file.exists(out[1])) return(terminar(out[1]))
    } else {
      anidado <- nm[es("csv[^/]*\\.zip$", nm)]
      if (length(anidado) > 0) {
        out <- tryCatch(unzip(zip_path, files = anidado[1], exdir = sub_dir,
                              junkpaths = TRUE), error = function(e) character(0))
        if (length(out) > 0 && file.exists(out[1])) {
          return(extraer_de_zip(out[1], patron, exdir))
        }
      }
    }
  }

  # 2. tar de Windows / bsdtar / unzip del sistema
  tar_win <- file.path(Sys.getenv("SystemRoot"), "System32", "tar.exe")
  globs <- c("*[Cc][Ss][Vv]*", "*[Cc][Vv][Ss]*")   # carpetas CSV, csv, CVS
  zp <- normalizePath(zip_path); sd <- normalizePath(sub_dir)
  if (.Platform$OS.type == "windows" && file.exists(tar_win)) {
    res <- suppressWarnings(system2(tar_win, c("-xf", shQuote(zp), "-C", shQuote(sd),
                                               shQuote(globs)), stdout = TRUE, stderr = TRUE))
  } else if (nzchar(Sys.which("bsdtar"))) {
    res <- suppressWarnings(system2(Sys.which("bsdtar"), c("-xf", shQuote(zp), "-C", shQuote(sd),
                                                           shQuote(globs)), stdout = TRUE, stderr = TRUE))
  } else if (nzchar(Sys.which("unzip"))) {
    res <- suppressWarnings(system2(Sys.which("unzip"), c("-o", "-q", shQuote(zp), shQuote(globs),
                                                          "-d", shQuote(sd)), stdout = TRUE, stderr = TRUE))
  } else {
    stop("unzip() de R no pudo abrir ", zip_path, " y no se encontró tar.exe ni unzip")
  }

  en_disco <- list.files(sub_dir, recursive = TRUE, full.names = TRUE)
  cand <- preferir_csv(en_disco[es(patron, basename(en_disco)) & es_datos(en_disco)])
  if (length(cand) > 0) return(terminar(cand[1]))
  anidado <- en_disco[es("csv[^/]*\\.zip$", basename(en_disco))]
  if (length(anidado) > 0) return(extraer_de_zip(anidado[1], patron, exdir))

  stop("No se encontró '", patron, "' en ", zip_path,
       if (length(res)) paste0("\n  salida de tar/unzip: ", paste(res, collapse = " | ")))
}

# Módulo de migración 2012 o 2019: un ZIP por mes descargado por el
# script 10. Devuelve las variables del módulo y el mes.
leer_modulo <- function(anio) {
  archivos <- sort(list.files(file.path(dir_mig_raw, paste0("modulo_", anio)),
                              pattern = "\\.zip$", full.names = TRUE))
  if (length(archivos) == 0) {
    stop("No están los ZIP del módulo ", anio, " en ", dir_mig_raw,
         ". Corre R/10_descarga_migracion_geih.R")
  }
  rbindlist(lapply(archivos, function(z) {
    mes <- as.integer(substr(basename(z), 1, 2))
    tmp <- tempfile("mod"); dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))
    nm <- unzip(z, list = TRUE)$Name
    datos <- nm[grepl("\\.(csv|dta|txt)$", nm, ignore.case = TRUE, useBytes = TRUE)]
    # Un ZIP puede traer el mismo archivo en CSV, DTA y SAV: se usa el CSV
    patron <- if (any(grepl("\\.csv$", datos, ignore.case = TRUE, useBytes = TRUE))) "\\.csv$" else "\\.(dta|txt)$"
    f  <- extraer_de_zip(z, patron, tmp)
    dt <- leer_archivo(f)
    dt[, MES := mes]
    cat(sprintf("  módulo %d-%02d: %s filas (%s)\n", anio, mes,
                format(nrow(dt), big.mark = ","), basename(f)))
    dt
  }), fill = TRUE)
}

# Características generales del Empalme: llaves, DPTO y FEX_C. Se guarda
# en data/GEIH_migracion/intermedio/ para no volver a descomprimir.
leer_empalme <- function(anio, meses = 1:12) {
  cache <- file.path(dir_mig_int, sprintf("empalme_%d_llaves.csv.gz", anio))
  if (file.exists(cache)) {
    dt <- fread(cache)
    if (setequal(unique(dt$MES), meses)) return(dt)
  }

  zip_anual <- file.path(dir_empalme, sprintf("GEIH_Empalme_%d.zip", anio))
  if (!file.exists(zip_anual)) stop("No se encontró ", zip_anual,
                                    ". Descárgalo del DANE (ver data/README.md)")
  internos <- unzip(zip_anual, list = TRUE)$Name
  internos <- internos[grepl("\\.zip$", internos, useBytes = TRUE)]

  dt <- rbindlist(lapply(meses, function(m) {
    z_mes <- internos[grepl(paste0("/", m, "\\. "), internos, useBytes = TRUE)]
    if (length(z_mes) == 0) return(NULL)
    tmp <- tempfile("emp"); dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))
    unzip(zip_anual, files = z_mes, exdir = tmp, junkpaths = TRUE)
    f  <- extraer_de_zip(file.path(tmp, basename(z_mes)),
                         "generales.*\\.csv$", tmp)
    cg <- leer_archivo(f)
    cg <- cg[, .(DIRECTORIO, SECUENCIA_P, ORDEN, MES = m, DPTO,
                 FEX_C = as.numeric(sub(",", ".", FEX_C)))]
    cat(sprintf("  empalme %d-%02d: %s personas\n", anio, m,
                format(nrow(cg), big.mark = ",")))
    cg
  }))
  fwrite(dt, cache)
  dt
}

# GEIH marco 2018 (2022 o 2024): un ZIP mensual con Migración.CSV y
# Características generales. Se guarda un extracto en
# data/GEIH_migracion/intermedio/ para no volver a descomprimir.
leer_geih_2018 <- function(anio) {
  cache <- file.path(dir_mig_int, sprintf("geih_%d_migracion.csv.gz", anio))
  if (file.exists(cache)) {
    dt <- fread(cache)
  } else {
    archivos <- sort(list.files(file.path(dir_mig_raw, paste0("geih_", anio)),
                                pattern = "\\.zip$", full.names = TRUE))
    if (length(archivos) == 0) {
      stop("No están los ZIP de la GEIH ", anio, " en ", dir_mig_raw,
           ". Corre R/10_descarga_migracion_geih.R")
    }
    dt <- rbindlist(lapply(archivos, function(z) {
      mes <- as.integer(substr(basename(z), 1, 2))
      tmp <- tempfile("geih"); dir.create(tmp)
      on.exit(unlink(tmp, recursive = TRUE))
      mig <- leer_archivo(extraer_de_zip(z, "Migraci.*\\.csv$", tmp))
      cg  <- leer_archivo(extraer_de_zip(z, "Caracter.*generales.*\\.csv$", tmp))
      vars_mig <- intersect(c("DIRECTORIO", "SECUENCIA_P", "ORDEN", "P3382",
                              "P3382S1", "P3384", "P3384S1"), names(mig))
      mig <- mig[, ..vars_mig]
      cg  <- cg[, .(DIRECTORIO, SECUENCIA_P, ORDEN, DPTO,
                    W18 = as.numeric(sub(",", ".", FEX_C18)))]
      x <- merge(mig, cg, by = c("DIRECTORIO", "SECUENCIA_P", "ORDEN"),
                 all.x = TRUE)
      cat(sprintf("  geih %d-%02d: %s personas en migración, %.2f%% con departamento\n",
                  anio, mes, format(nrow(x), big.mark = ","),
                  100 * mean(!is.na(x$DPTO))))
      x[, MES := mes]
      x
    }), fill = TRUE)
    fwrite(dt, cache)
  }
  dt
}

# ---------------------------------------------------------------------
# FUNCIONES DE CÁLCULO
# ---------------------------------------------------------------------

# Matriz origen-destino en miles, promedio mensual, completa (24 x 23)
matriz_flujos <- function(dt, origen, peso, n_meses) {
  x <- dt[!is.na(get(origen)) & !is.na(DPTO) & !is.na(get(peso)),
          .(out = get(origen), `in` = DPTO, w = get(peso))]
  x <- x[out %in% dptos_mig$cod & `in` %in% dptos_mig$cod & out != `in`]
  x <- x[, .(val = sum(w) / n_meses / 1000), by = .(out, `in`)]
  grilla <- CJ(out = dptos_mig$cod, `in` = dptos_mig$cod)[out != `in`]
  x <- merge(grilla, x, by = c("out", "in"), all.x = TRUE)
  x[is.na(val), val := 0]
  x[, out_dpto := dptos_mig$corto[match(out, dptos_mig$cod)]]
  x[, in_dpto  := dptos_mig$corto[match(`in`, dptos_mig$cod)]]
  setcolorder(x, c("out", "in", "out_dpto", "in_dpto", "val"))
  x[]
}

# Población promedio mensual por departamento (miles), para las tasas
poblacion_dpto <- function(dt, peso, n_meses) {
  dt[DPTO %in% dptos_mig$cod & !is.na(get(peso)),
     .(poblacion = sum(get(peso)) / n_meses / 1000), by = .(cod = DPTO)]
}

# Emigrantes, inmigrantes, saldo y tasas por mil habitantes
tasas_dpto <- function(flujos, pob) {
  emi <- flujos[, .(emigrantes = sum(val)), by = .(cod = out)]
  inm <- flujos[, .(inmigrantes = sum(val)), by = .(cod = `in`)]
  x <- Reduce(function(a, b) merge(a, b, by = "cod", all = TRUE),
              list(dptos_mig[, .(cod, departamento = nombre, region)], pob, emi, inm))
  x[, saldo := inmigrantes - emigrantes]
  x[, `:=`(tasa_emigracion = 1000 * emigrantes / poblacion,
           tasa_inmigracion = 1000 * inmigrantes / poblacion,
           tasa_neta = 1000 * saldo / poblacion)]
  x[]
}

exportar_csv <- function(flujos, nombre) {
  fwrite(flujos[, .(out, `in`, out_dpto, in_dpto, val = round(val, 1))],
         file.path(dir_tab_mig, nombre))
}

# ---------------------------------------------------------------------
# 1. CONSTRUCCIÓN DE LAS BASES POR AÑO
# ---------------------------------------------------------------------
cat("\n=== Leyendo microdatos ===\n")
bases <- list()

for (anio in c(2012, 2019)) {
  mod <- leer_modulo(anio)
  # Solo los meses que trae el módulo (2012 va de febrero a diciembre)
  emp <- leer_empalme(anio, meses = sort(unique(mod$MES)))
  dt  <- merge(mod, emp, by = c("DIRECTORIO", "SECUENCIA_P", "ORDEN", "MES"),
               all.x = TRUE)
  cat(sprintf("  %d: %.2f%% de las personas del módulo encontradas en el Empalme\n",
              anio, 100 * mean(!is.na(dt$DPTO))))
  dt[, W11 := as.numeric(sub(",", ".", FEX_C_2011))]
  dt[, W18 := FEX_C]

  if (anio == 2012) {
    for (v in c("P6074", "P6075", "P6076", "P6076S1")) set(dt, j = v, value = as.integer(dt[[v]]))
    dt[, orig_5y := fifelse(P6074 == 2 & P6075 %in% 1:5 & P6076 == 2, P6076S1, NA_integer_)]
    dt[, orig_1y := fifelse(P6074 == 2 & P6075 == 1 & P6076 == 2, P6076S1, NA_integer_)]
  } else {
    for (v in c("P755", "P755S1", "P753", "P753S1")) set(dt, j = v, value = as.integer(dt[[v]]))
    dt[, orig_5y := fifelse(P755 == 3, P755S1, NA_integer_)]
    dt[, orig_1y := fifelse(P753 == 3, P753S1, NA_integer_)]
  }
  bases[[as.character(anio)]] <- dt
  rm(mod, emp, dt); gc()
}

for (anio_ext in anios_ext) {
  dt <- leer_geih_2018(anio_ext)
  for (v in c("P3382", "P3382S1", "P3384", "P3384S1")) set(dt, j = v, value = as.integer(dt[[v]]))
  cat(sprintf("  %d: distribución de P3382 (dónde vivía hace 5 años):\n", anio_ext))
  print(dt[, .N, keyby = P3382])
  dt[, orig_5y := fifelse(P3382 == 3, P3382S1, NA_integer_)]
  dt[, orig_1y := fifelse(P3384 == 3, P3384S1, NA_integer_)]
  dt[, W11 := NA_real_]
  bases[[as.character(anio_ext)]] <- dt
  rm(dt); gc()
}

# ---------------------------------------------------------------------
# 2. FLUJOS, TASAS Y EXPORTACIÓN
# ---------------------------------------------------------------------
cat("\n=== Calculando flujos ===\n")
largo <- list(); tasas <- list()

for (a in names(bases)) {
  dt <- bases[[a]]
  n_meses <- uniqueN(dt$MES)
  for (h in c("5y", "1y")) {
    for (w in c("W18", "W11")) {
      if (all(is.na(dt[[w]]))) next
      f <- matriz_flujos(dt, paste0("orig_", h), w, n_meses)
      factor <- if (w == "W18") "CNPV 2018" else "CNPV 2005 (fex_c_2011)"
      largo[[paste(a, h, w)]] <- cbind(anio = as.integer(a), horizonte = h,
                                       factor = factor, f)
      tasas[[paste(a, h, w)]] <- cbind(anio = as.integer(a), horizonte = h,
                                       factor = factor,
                                       tasas_dpto(f, poblacion_dpto(dt, w, n_meses)))
      nombre <- sprintf("flows_%s_%s%s.csv", h, a, if (w == "W11") "_fex2011" else "")
      exportar_csv(f, nombre)
      cat(sprintf("  %s %s %-24s total %8.1f mil  (%d meses) -> %s\n",
                  a, h, factor, sum(f$val), n_meses, nombre))
    }
  }
}

largo <- rbindlist(largo)
tasas <- rbindlist(tasas)

# ---------------------------------------------------------------------
# 3. RÉPLICA: 2019 CONTRA flows_5y_2019.csv DE ACOSTA Y GU
# ---------------------------------------------------------------------
replica <- NULL
if (file.exists(path_ref_2019)) {
  ref <- fread(path_ref_2019)[, .(out, `in`, val_AcostaGu = val)]
  replica <- merge(
    ref,
    dcast(largo[anio == 2019 & horizonte == "5y"], out + `in` ~ factor,
          value.var = "val"),
    by = c("out", "in"), all = TRUE)
  setnames(replica, c("CNPV 2005 (fex_c_2011)", "CNPV 2018"),
           c("val_fex2011", "val_fex2018"), skip_absent = TRUE)
  replica[, `:=`(out_dpto = dptos_mig$corto[match(out, dptos_mig$cod)],
                 in_dpto  = dptos_mig$corto[match(`in`, dptos_mig$cod)])]
  cat("\n=== Réplica 2019 (5 años) contra Acosta y Gu ===\n")
  for (v in intersect(c("val_fex2011", "val_fex2018"), names(replica))) {
    cat(sprintf("  %s: correlación %.4f | total propio %.1f vs. %.1f mil | diferencia absoluta media %.2f mil\n",
                v, cor(replica$val_AcostaGu, replica[[v]], use = "complete.obs"),
                sum(replica[[v]], na.rm = TRUE), sum(replica$val_AcostaGu, na.rm = TRUE),
                mean(abs(replica[[v]] - replica$val_AcostaGu), na.rm = TRUE)))
  }
  fwrite(replica, file.path(dir_tab_mig, "replica_flows_5y_2019_vs_AcostaGu.csv"))
} else {
  cat("\nNo se encontró ", path_ref_2019, "; se omite la comparación.\n", sep = "")
}

# Resumen nacional por año: migrantes interdepartamentales y tasa
resumen <- tasas[, .(poblacion = sum(poblacion, na.rm = TRUE),
                     migrantes = sum(emigrantes, na.rm = TRUE)),
                 by = .(anio, horizonte, factor)]
resumen[, tasa_por_mil := 1000 * migrantes / poblacion]
cat("\n=== Resumen nacional (miles) ===\n")
print(resumen)

wb <- createWorkbook()
hojas <- list(
  "LEAME" = data.table(nota = c(
    "Flujos de migración interdepartamental, GEIH. Unidades: miles de personas, promedio mensual del año.",
    "5y: residencia hace 5 años (2012: llegó al municipio hace 5 años o menos). 1y: residencia hace 12 meses.",
    "factor CNPV 2018: FEX_C del Empalme (2012, 2019) y FEX_C18 (2022, 2024). Comparable entre años.",
    "factor CNPV 2005 (fex_c_2011): el que usan Acosta y Gu (2022); solo 2012 y 2019.",
    "2012: el módulo del DANE no trae enero; el promedio es sobre 11 meses.",
    "Universo: 24 departamentos (23 + Bogotá), sistema cerrado. out = origen, in = destino.",
    "Tasas por mil habitantes del departamento (población expandida de la misma encuesta).")),
  "flujos" = largo,
  "tasas_dpto" = tasas,
  "resumen_nacional" = resumen)
if (!is.null(replica)) hojas[["replica_2019"]] <- replica
for (h in names(hojas)) {
  addWorksheet(wb, h)
  writeData(wb, h, hojas[[h]])
}
saveWorkbook(wb, file.path(dir_tab_mig, "flujos_migracion_geih.xlsx"),
             overwrite = TRUE)

cat("\nResultados en ", dir_tab_mig, "\n", sep = "")

rm(bases); gc()
if (exists("clean_session")) clean_session()
