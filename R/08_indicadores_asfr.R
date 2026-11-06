# =====================================================================
# 08_indicadores_asfr.R — Descomposición del TFR por etapa reproductiva
#
# Lee las tablas de ASFR que generan los scripts 01 a 04 y descompone el
# TFR en las tasas específicas de cada tramo de edad de la madre, a nivel
# nacional, regional y departamental, en nivel y en participación
# porcentual.
#
# Correrlo después de 01 y 02.
#
# Salida: output/tablas/Indicadores_ASFR.xlsx
#         output/graficas/resumen/TFR_ASFR_descomposicion_*.png
#         output/graficas/tfr_asfr_descomposicion/departamental/
#         output/graficas/tfr_asfr_descomposicion/regional/
# =====================================================================

source("R/00_setup.R")

# ---------------------------------------------------------------------
# 1. CARGAR ASFR
# ---------------------------------------------------------------------
# Lee una hoja si existe; si no, devuelve NULL
leer_hoja <- function(archivo, hoja) {
  ruta <- file.path(dir_tablas, archivo)
  if (!file.exists(ruta)) {
    message("Falta ", archivo, "; se omite esa fuente.")
    return(NULL)
  }
  hojas <- readxl::excel_sheets(ruta)
  if (!hoja %in% hojas) {
    message(archivo, " no tiene la hoja ", hoja, "; se omite.")
    return(NULL)
  }
  read_excel(ruta, sheet = hoja)
}

# Los censos IPUMS llegan hasta 2004; el CNPV 2018 extiende la serie
# hasta 2015. El ASFR de 2018 solo tiene edades de la madre en múltiplos
# de cinco, porque ese censo reporta la edad en grupos quinquenales.
asfr_nac <- bind_rows(
  leer_hoja("TFR_nacional_1958_2005.xlsx", "ASFR"),
  leer_hoja("TFR_nacional_2018.xlsx", "ASFR")
)

asfr_dpto <- bind_rows(
  leer_hoja("TFR_departamental_1958_2005.xlsx", "ASFR"),
  leer_hoja("TFR_departamental_2018.xlsx", "ASFR_retro")
)

cat(sprintf("ASFR nacional: %d filas, años %d-%d\n",
            nrow(asfr_nac), min(asfr_nac$year), max(asfr_nac$year)))
cat(sprintf("ASFR departamental: %d filas, años %d-%d\n",
            nrow(asfr_dpto), min(asfr_dpto$year), max(asfr_dpto$year)))

# Revisa que el ASFR tenga una sola fila por combinación y que no haya
# tasas negativas: si hubiera filas repetidas, las áreas apiladas se
# dibujarían superpuestas y la composición pasaría del 100%.
revisar_asfr <- function(df, vars_clave, etiqueta) {

  repetidas <- df %>%
    count(across(all_of(vars_clave)), name = "n") %>%
    filter(n > 1)

  if (nrow(repetidas) > 0) {
    warning(etiqueta, ": ", nrow(repetidas),
            " combinaciones repetidas; se suman al agregar.")
    print(as.data.frame(head(repetidas, 5)), row.names = FALSE)
  }

  negativas <- df %>% filter(!is.na(asfr), asfr < 0)
  if (nrow(negativas) > 0) {
    warning(etiqueta, ": ", nrow(negativas),
            " tasas negativas; se llevan a cero.")
    print(as.data.frame(head(negativas, 5)), row.names = FALSE)
  }

  invisible(NULL)
}

# Deja una sola fila por combinación. Si la tabla viene desagregada
# (por ejemplo por censo), las tasas no se pueden sumar ni promediar:
# se reagregan desde los totales, asfr = total de hijos / total de
# mujeres. Solo si esos totales no están se recurre al promedio.
consolidar_asfr <- function(df, vars_clave, etiqueta) {

  revisar_asfr(df, vars_clave, etiqueta)

  df <- df %>% mutate(asfr = pmax(asfr, 0))

  consolidado <- if (all(c("total_child", "total_women") %in% names(df))) {
    df %>%
      group_by(across(all_of(vars_clave))) %>%
      summarise(
        total_child = sum(total_child, na.rm = TRUE),
        total_women = sum(total_women, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(asfr = if_else(total_women > 0,
                            total_child / total_women, NA_real_)) %>%
      select(all_of(vars_clave), total_child, total_women, asfr)
  } else {
    df %>%
      group_by(across(all_of(vars_clave))) %>%
      summarise(asfr = mean(asfr, na.rm = TRUE), .groups = "drop")
  }

  # Sin tasas faltantes ni infinitas: si se dejaran, los rangos darían
  # Inf y las figuras descartarían filas silenciosamente
  descartadas <- sum(!is.finite(consolidado$asfr))
  if (descartadas > 0) {
    message(etiqueta, ": se descartan ", descartadas,
            " combinaciones sin tasa estimable.")
  }

  consolidado %>% filter(is.finite(asfr))
}

asfr_edad <- asfr_nac %>%
  rename(edad = mother_age_at_birth) %>%
  filter(edad >= 15, edad <= 49) %>%
  consolidar_asfr(c("year", "edad"), "ASFR nacional")

asfr_edad_dpto <- asfr_dpto %>%
  rename(edad = mother_age_at_birth) %>%
  filter(edad >= 15, edad <= 49) %>%
  consolidar_asfr(c("department", "year", "edad"), "ASFR departamental")

# El ASFR del censo 2018 ya viene en la escala correcta: cada tasa es
# hijos por mujer del grupo de edad correspondiente, y su suma reproduce
# el TFR del año. No se reescala por la amplitud del intervalo.
#
# Lo que sí cambia es el detalle: los censos IPUMS traen edad simple y
# el CNPV 2018 solo múltiplos de cinco, así que la composición por
# tramos es más gruesa en esos años.
cobertura <- bind_rows(
  asfr_edad %>% count(year, name = "edades") %>% mutate(fuente = "nacional"),
  asfr_edad_dpto %>% count(department, year, name = "edades") %>%
    mutate(fuente = "departamental") %>% select(year, edades, fuente)
) %>%
  count(fuente, edades, name = "casos")

cat("\nEdades distintas por año (detalle del ASFR):\n")
print(as.data.frame(cobertura), row.names = FALSE)


# ---------------------------------------------------------------------
# 2. DESCOMPOSICIÓN DEL TFR POR ETAPA REPRODUCTIVA
# ---------------------------------------------------------------------
# El TFR es la suma de las tasas específicas, así que al sumarlas dentro
# de cada tramo de edad se obtiene cuántos hijos aporta cada etapa. Los
# tramos se apilan y su altura total es el TFR del año.
#
# El panel se completa con ceros para que ninguna etapa falte: si en
# algún año una etapa no tiene nacimientos observados, su fila faltaría
# y el área apilada dejaría un hueco. Se usa nesting() para completar
# solo dentro de las combinaciones de departamento y año que existen, y
# no inventar años que ese departamento nunca observó.
etapa_reproductiva <- function(edad) {
  cut(edad,
      breaks = c(15, 20, 35, 40, 50),
      right  = FALSE,
      labels = c("Adolescente (15-19)",
                 "Edad central (20-34)",
                 "Edad avanzada (35-39)",
                 "Edad tardía (40 y más)"))
}

# Misma descomposición para cualquier nivel de agregación: se le pasan
# las variables que identifican la unidad (ninguna para el nacional,
# "department" o "region" para los otros).
descomponer_tfr <- function(df, vars_grupo) {

  if (is.null(df)) return(NULL)

  base <- df %>%
    mutate(etapa = etapa_reproductiva(edad)) %>%
    filter(!is.na(etapa)) %>%
    group_by(across(all_of(c(vars_grupo, "year", "etapa")))) %>%
    summarise(tfr_parcial = sum(asfr, na.rm = TRUE), .groups = "drop")

  base <- if (length(vars_grupo) == 0) {
    base %>% complete(year, etapa, fill = list(tfr_parcial = 0))
  } else {
    base %>%
      complete(nesting(!!!syms(c(vars_grupo, "year"))), etapa,
               fill = list(tfr_parcial = 0))
  }

  base %>%
    group_by(across(all_of(c(vars_grupo, "year")))) %>%
    mutate(
      total_anio    = sum(tfr_parcial, na.rm = TRUE),
      participacion = if_else(total_anio > 0,
                              100 * tfr_parcial / total_anio, NA_real_)
    ) %>%
    ungroup() %>%
    filter(!is.na(participacion)) %>%
    select(-total_anio)
}

TFR_descomposicion      <- descomponer_tfr(asfr_edad, character(0))
TFR_descomposicion_dpto <- descomponer_tfr(asfr_edad_dpto, "department")

# Verificación: la composición debe sumar 100% en cada año y departamento
revisar_suma <- function(df, vars_grupo, etiqueta) {
  if (is.null(df)) return(invisible(NULL))
  desvios <- df %>%
    group_by(across(all_of(vars_grupo))) %>%
    summarise(suma = sum(participacion, na.rm = TRUE), .groups = "drop") %>%
    filter(abs(suma - 100) > 0.01)
  if (nrow(desvios) > 0) {
    warning(etiqueta, ": ", nrow(desvios),
            " casos donde la composición no suma 100%.")
    print(as.data.frame(head(desvios, 10)), row.names = FALSE)
  } else {
    cat(etiqueta, ": la composición suma 100% en todos los casos.\n")
  }
}

revisar_suma(TFR_descomposicion, "year", "Descomposición nacional")
revisar_suma(TFR_descomposicion_dpto, c("department", "year"),
             "Descomposición departamental")

# ---------------------------------------------------------------------
# 3. EXPORTAR
# ---------------------------------------------------------------------
write.xlsx(
  list(
    "Descomposicion_nacional" = TFR_descomposicion,
    "Descomposicion_dpto"     = TFR_descomposicion_dpto
  ),
  file = file.path(dir_tablas, "Indicadores_ASFR.xlsx"),
  overwrite = TRUE
)

# ---------------------------------------------------------------------
# 4. QUE GRAFICA: DESCOMPOSICIÓN EN NIVEL Y EN PORCENTAJE
# ---------------------------------------------------------------------
# El área apilada en nivel suma el TFR del año; la versión porcentual
# muestra el cambio de composición sin el efecto del nivel.
# col_etapas está definido en 00_setup.R, para que el 09 use los mismos
# nombres de etapa en su versión pastel

# Descomposición en nivel. La leyenda va en dos filas: las cuatro etapas
# arriba y el nivel de reemplazo debajo.
fig_nivel <- function(df, titulo, tamano = 13, por = 5) {
  df %>%
    filter(!is.na(etapa)) %>%
    ggplot(aes(x = year, y = tfr_parcial, fill = etapa)) +
    geom_area() +
    scale_fill_manual(values = col_etapas) +
    escala_anios(by = por) +
    escala_fecundidad() +
    marcas_planificacion() +
    leyenda_dos_filas() +
    labs(x = "Año", y = "TFR", title = titulo) +
    theme_fecundidad(base_size = tamano)
}

# La misma descomposición en participación porcentual
fig_pct <- function(df, titulo, tamano = 13, por = 5) {
  df %>%
    filter(!is.na(etapa)) %>%
    ggplot(aes(x = year, y = participacion, fill = etapa)) +
    geom_area() +
    scale_fill_manual(values = col_etapas) +
    escala_anios(by = por) +
    scale_y_continuous(breaks = seq(0, 100, by = 25)) +
    coord_cartesian(ylim = c(0, 100)) +
    marcas_planificacion() +
    labs(x = "Año", y = "% del TFR", title = titulo) +
    theme_fecundidad(base_size = tamano)
}

# --- Nacional --------------------------------------------------------
ggsave(file.path(dir_graf_resumen, "TFR_ASFR_descomposicion_nacional.png"),
       fig_nivel(TFR_descomposicion,
                 "Composición del TFR por etapa reproductiva"),
       width = 10, height = 6, dpi = 300)

ggsave(file.path(dir_graf_resumen, "TFR_ASFR_descomposicion_nacional_pct.png"),
       fig_pct(TFR_descomposicion,
               "Participación de cada etapa reproductiva en el TFR"),
       width = 10, height = 6, dpi = 300)

# --- Panel con los 22 departamentos ----------------------------------
ggsave(
  file.path(dir_graf_resumen, "TFR_ASFR_descomposicion_departamental.png"),
  fig_nivel(TFR_descomposicion_dpto,
            "Composición del TFR por etapa reproductiva y departamento",
            tamano = 11, por = 20) + facet_wrap(~department),
  width = 14, height = 10, dpi = 300)

ggsave(
  file.path(dir_graf_resumen, "TFR_ASFR_descomposicion_departamental_pct.png"),
  fig_pct(TFR_descomposicion_dpto,
          "Participación de cada etapa reproductiva en el TFR",
          tamano = 11, por = 20) + facet_wrap(~department),
  width = 14, height = 10, dpi = 300)

# --- Una figura por departamento -------------------------------------
for (dept in sort(unique(na.omit(TFR_descomposicion_dpto$department)))) {

  datos <- TFR_descomposicion_dpto %>%
    filter(department == dept, !is.na(etapa))

  if (nrow(datos) == 0) {
    warning("Sin datos de descomposición para ", dept, "; se omite.")
    next
  }

  archivo <- gsub(" ", "_", dept)

  ggsave(file.path(dir_graf_descomposicion,
                   sprintf("TFR_ASFR_descomposicion_%s.png", archivo)),
         fig_nivel(datos, dept), width = 9, height = 5.5, dpi = 300)

  ggsave(file.path(dir_graf_descomposicion,
                   sprintf("TFR_ASFR_descomposicion_pct_%s.png", archivo)),
         fig_pct(datos, dept), width = 9, height = 5.5, dpi = 300)
}

# --- Una figura por región, con un panel por departamento ------------
por_region(TFR_descomposicion_dpto, function(datos, reg, archivo) {

  ggsave(file.path(dir_graf_descomposicion_reg,
                   sprintf("TFR_ASFR_descomposicion_%s.png", archivo)),
         fig_nivel(datos, reg, tamano = 11, por = 20) +
           facet_wrap(~department),
         width = 12, height = 7, dpi = 300)

  ggsave(file.path(dir_graf_descomposicion_reg,
                   sprintf("TFR_ASFR_descomposicion_pct_%s.png", archivo)),
         fig_pct(datos, reg, tamano = 11, por = 20) +
           facet_wrap(~department),
         width = 12, height = 7, dpi = 300)
})

cat("\nResultados guardados en", dir_tablas, "y", dir_graf, "\n")

clean_session()
