# =====================================================================
# 09_figuras_tfr_fcc.R — Figuras de TFR, FCC y mujeres sin hijos
#
# Lee las tablas que generan los scripts 01 a 06, y produce sus
# figuras. Los scripts 07 y 08 generan sus propias gráficas.
#
# El TFR departamental usa además la descomposición por etapa que
# calcula el 08, así que conviene correr ese antes. Si falta esa tabla,
# el TFR sale como líneas.
#
# Cada indicador sale en dos niveles. En departamental/ va una figura
# por departamento, contra la serie nacional. En regional/ va una figura
# por región, con un panel por cada departamento que la compone y la
# serie nacional repetida de fondo: no es una serie agregada de la
# región, sino sus departamentos puestos lado a lado para compararlos.
#
# Si falta una tabla, la sección correspondiente se omite con un aviso.
# =====================================================================

source("R/00_setup.R")

# Lee una hoja si el archivo existe; si no, devuelve NULL
leer_tabla <- function(archivo, hoja) {
  ruta <- file.path(dir_tablas, archivo)
  if (!file.exists(ruta)) {
    message("Falta ", archivo, "; se omiten sus gráficas.")
    return(NULL)
  }
  read_excel(ruta, sheet = hoja)
}

# Guarda una figura. Si falla, avisa y sigue con las demás: así un
# problema puntual no impide que se generen el resto de las figuras.
figuras_ok <- 0
figuras_error <- character()

guardar <- function(nombre, plot, carpeta = dir_graf_resumen,
                    ancho = 10, alto = 6) {
  tryCatch({
    ggsave(file.path(carpeta, nombre), plot,
           width = ancho, height = alto, dpi = 300)
    figuras_ok <<- figuras_ok + 1
  }, error = function(e) {
    figuras_error <<- c(figuras_error,
                        sprintf("%s: %s", nombre, conditionMessage(e)))
    message("No se pudo generar ", nombre, ": ", conditionMessage(e))
  })
}

# Una figura por unidad (departamento o región) contra la referencia
# nacional. Sirve para los tres indicadores y para los dos niveles, así
# que las series salen siempre con el mismo aspecto.
#
# variable: "department" o "region"; etiqueta: cómo se llama la serie en
# la leyenda.
figuras_por_unidad <- function(datos, datos_nac, variable, columna, eje_x,
                               etiqueta_x, etiqueta_y, patron, carpeta,
                               etiqueta = "Departamento",
                               escala = NULL, limites = NULL,
                               puntos = TRUE) {

  if (is.null(datos) || is.null(datos_nac)) return(invisible(NULL))

  niveles <- c(etiqueta, "Total Nacional")

  # Las regiones vienen como factor: se pasan a texto para que sirvan de
  # título y de nombre de archivo
  datos  <- datos %>% mutate(across(all_of(variable), as.character))
  unidades <- sort(unique(na.omit(datos[[variable]])))

  for (unidad in unidades) {

    df <- bind_rows(
      datos %>%
        filter(.data[[variable]] == unidad) %>%
        transmute(x = .data[[eje_x]], y = .data[[columna]], serie = etiqueta),
      datos_nac %>%
        transmute(x = .data[[eje_x]], y = .data[[columna]],
                  serie = "Total Nacional")
    ) %>%
      filter(is.finite(y)) %>%
      mutate(serie = factor(serie, levels = niveles))

    if (nrow(df) == 0) next

    p <- ggplot(df, aes(x = x, y = y, color = serie)) +
      geom_line(linewidth = 1)

    if (puntos) p <- p + geom_point(size = 1.6)

    p <- p +
      scale_color_manual(values = setNames(c(col_dpto, col_total), niveles)) +
      labs(x = etiqueta_x, y = etiqueta_y, title = unidad) +
      theme_fecundidad()

    if (!is.null(escala))  p <- p + escala
    if (!is.null(limites)) p <- p + coord_cartesian(ylim = limites)

    guardar(sprintf(patron, gsub(" ", "_", unidad)), p,
            carpeta = carpeta, ancho = 9, alto = 5.5)
  }
}

# Una figura por región, con un panel por cada departamento que la
# compone y la serie nacional repetida de fondo como referencia.
figuras_por_region <- function(datos, datos_nac, columna, eje_x,
                               etiqueta_x, etiqueta_y, patron, carpeta,
                               escala = NULL,
                               panel_ancho = 3.5, panel_alto = 3.3,
                               ncol_max = 3) {

  if (is.null(datos) || is.null(datos_nac)) return(invisible(NULL))

  por_region(datos, function(datos_reg, reg, archivo) {

    # Cada panel (un departamento) mide lo mismo en TODAS las figuras
    # regionales: panel_ancho x panel_alto es fijo. La reticula usa como
    # maximo ncol_max columnas y solo las filas que hagan falta segun el
    # numero de departamentos, asi que lo que cambia entre figuras es el
    # tamano total de la imagen, no el de cada panel. Una region con
    # pocos departamentos (p. ej. 3, una sola fila) sale a la mitad de
    # alto que una de dos filas.
    n_paneles <- dplyr::n_distinct(datos_reg$department)
    ncol <- min(ncol_max, n_paneles)
    nrow <- ceiling(n_paneles / ncol)

    p <- ggplot() +
      geom_line(data = datos_nac,
                aes(x = .data[[eje_x]], y = .data[[columna]],
                    color = "Total Nacional"),
                linewidth = 0.8) +
      geom_line(data = datos_reg,
                aes(x = .data[[eje_x]], y = .data[[columna]],
                    color = "Departamento"),
                linewidth = 0.9) +
      facet_wrap(~department, ncol = ncol) +
      scale_color_manual(values = c("Departamento"   = col_dpto,
                                    "Total Nacional" = col_total)) +
      labs(x = etiqueta_x, y = etiqueta_y, title = reg) +
      theme_fecundidad(base_size = 11)

    if (!is.null(escala)) p <- p + escala

    # Ancho/alto = tamano de panel * reticula + un margen fijo para
    # titulos, ejes y leyenda (constante entre figuras).
    guardar(sprintf(patron, archivo), p, carpeta = carpeta,
            ancho = panel_ancho * ncol + 1.5,
            alto  = panel_alto  * nrow + 1.5)
  })
}

# =====================================================================
# TFR NACIONAL (scripts 01 y 03)
#
# La serie combina los censos IPUMS, que llegan hasta 2004, con el CNPV
# 2018, que la extiende hasta 2015. Como el censo 2018 reporta la edad
# en grupos quinquenales, sus años van de cinco en cinco.
# =====================================================================
TFR_national           <- leer_tabla("TFR_nacional_1958_2005.xlsx", "TFR")
TFR_national_por_censo <- leer_tabla("TFR_nacional_1958_2005.xlsx", "TFR_por_censo")
TFR_national_2018      <- leer_tabla("TFR_nacional_2018.xlsx", "TFR")

# Une dos fuentes dejando constancia de cuál aporta cada observación.
# Solo concatena si la segunda tabla trae las columnas necesarias, y
# homogeniza el tipo de las variables de agrupación para que bind_rows
# no falle.
unir_fuentes <- function(ipums, dane, vars_grupo, vars_valor) {

  if (is.null(ipums)) return(NULL)

  columnas <- c(vars_grupo, vars_valor)

  preparar <- function(df, etiqueta) {
    df %>%
      select(any_of(columnas)) %>%
      mutate(across(any_of(vars_grupo), as.character),
             fuente = etiqueta)
  }

  base <- preparar(ipums, "Censos IPUMS")

  if (!is.null(dane)) {
    faltantes <- setdiff(c(vars_grupo, vars_valor[1]), names(dane))
    if (length(faltantes) > 0) {
      message("La tabla del CNPV 2018 no trae: ",
              paste(faltantes, collapse = ", "), ". Se omite.")
    } else {
      base <- bind_rows(base, preparar(dane, "CNPV 2018"))
    }
  }

  # Se descartan las filas sin valor: las figuras las eliminarían con un
  # aviso y podrían dejar paneles vacíos
  faltan <- sum(!is.finite(base[[vars_valor[2]]]))
  if (faltan > 0) {
    message("Se descartan ", faltan, " filas sin valor en ",
            vars_valor[2], ".")
  }

  base %>%
    filter(is.finite(.data[[vars_valor[2]]])) %>%
    arrange(across(all_of(c(vars_grupo, vars_valor[1]))))
}

unir_tfr <- function(ipums, dane, vars_grupo) {
  unir_fuentes(ipums, dane, vars_grupo,
               c("year", "tfr", "tfr_lower", "tfr_upper"))
}

# La serie por censo solo existe para los censos IPUMS; el CNPV 2018
# aporta un único censo, así que se añade con su propia etiqueta
if (!is.null(TFR_national_por_censo) && !is.null(TFR_national_2018)) {
  TFR_national_por_censo <- bind_rows(
    TFR_national_por_censo %>% select(year, census_year, tfr),
    TFR_national_2018 %>% transmute(year, census_year = 2018, tfr)
  ) %>%
    arrange(census_year, year)
}

TFR_national <- unir_tfr(TFR_national, TFR_national_2018, character(0))

if (!is.null(TFR_national)) {

  p <- TFR_national %>%
    filter(year >= 1958) %>%
    ggplot(aes(x = year, y = tfr)) +
    geom_ribbon(aes(ymin = tfr_lower, ymax = tfr_upper),
                fill = col_banda_fill, color = col_banda_line,
                linewidth = 0.3) +
    geom_line(color = col_nacional, linetype = "dashed", linewidth = 1) +
    geom_point(size = 1.4, color = col_nacional) +
    escala_anios() +
    marcas_planificacion() +
    labs(x = "Año", y = "TFR",
         title = "Tasa de Fecundidad Total en Colombia") +
    theme_fecundidad()

  guardar("TFR_nacional_1958_2018.png", p)

  if (!is.null(TFR_national_por_censo)) {
    p_censos <- ggplot() +
      geom_ribbon(data = TFR_national %>% filter(year >= 1958),
                  aes(x = year, ymin = tfr_lower, ymax = tfr_upper),
                  fill = col_banda_fill, color = col_banda_line,
                  linewidth = 0.3) +
      geom_line(data = TFR_national_por_censo %>% filter(year >= 1958),
                aes(x = year, y = tfr, color = factor(census_year)),
                linewidth = 1) +
      # El censo 2018 aporta solo tres años, espaciados de cinco en
      # cinco: se marcan con puntos para que no se lean como una serie
      # continua
      geom_point(data = TFR_national_por_censo %>%
                   filter(census_year == max(census_year)),
                 aes(x = year, y = tfr, color = factor(census_year)),
                 size = 2) +
      geom_line(data = TFR_national %>% filter(year >= 1958),
                aes(x = year, y = tfr),
                color = col_nacional, linetype = "dashed", linewidth = 1) +
      scale_color_manual(
        values = col_series(n_distinct(TFR_national_por_censo$census_year))) +
      escala_anios() +
      marcas_planificacion() +
      labs(x = "Año", y = "TFR",
           title = "Tasa de Fecundidad Total por censo") +
      theme_fecundidad()

    guardar("TFR_nacional_por_censo.png", p_censos)
  }
}

# =====================================================================
# TFR DEPARTAMENTAL (scripts 02 y 04, con la descomposición del 08)
#
# El TFR del departamento se dibuja como área apilada por etapa
# reproductiva, en tonos pastel, y encima va la línea del total
# nacional. El alto del área es el TFR del departamento —la suma de las
# tasas específicas— así que la figura muestra a la vez el nivel, su
# composición por edad de la madre y la distancia contra el país.
#
# La descomposición la calcula el script 08. Si esa tabla falta, se
# avisa y se cae a la versión de solo líneas.
# =====================================================================
TFR_depto      <- leer_tabla("TFR_departamental_1958_2005.xlsx", "TFR")
TFR_depto_2018 <- leer_tabla("TFR_departamental_2018.xlsx", "TFR_retro")

TFR_depto <- unir_tfr(TFR_depto, TFR_depto_2018, "department")

Desc_dpto <- leer_tabla("Indicadores_ASFR.xlsx", "Descomposicion_dpto")

if (!is.null(Desc_dpto)) {
  Desc_dpto <- Desc_dpto %>%
    filter(!is.na(etapa), year >= 1958) %>%
    mutate(etapa = factor(etapa, levels = names(col_etapas_pastel)))
}

if (!is.null(TFR_depto)) {

  tfr_dpto_plot <- TFR_depto %>% filter(year >= 1958)

  # Línea nacional: la TFR nacional (IPUMS + CNPV 2018), que suma los
  # conteos ajustados de todos los departamentos. No se usa el promedio
  # simple de las TFR departamentales, que da el mismo peso a San Andrés
  # que a Bogotá y sobrestima el nivel del país.
  if (!is.null(TFR_national)) {
    tfr_nacional_ref <- TFR_national %>%
      filter(year >= 1958) %>%
      select(year, tfr)
  } else {
    warning("Falta la TFR nacional; la línea 'Total Nacional' de las ",
            "figuras departamentales y regionales se omite.")
    tfr_nacional_ref <- tibble(year = numeric(), tfr = numeric())
  }

  # Área apilada del departamento + línea nacional encima. 'datos' trae
  # la descomposición ya filtrada a los departamentos que se dibujan.
  fig_tfr_area <- function(datos, titulo, ncol = NULL) {

    p <- ggplot() +
      geom_area(data = datos,
                aes(x = year, y = tfr_parcial, fill = etapa)) +
      geom_line(data = tfr_nacional_ref,
                aes(x = year, y = tfr, color = "Total Nacional"),
                linewidth = 0.9)

    # Con un solo departamento el nombre ya va en el título: la franja
    # del panel sobraría
    if (n_distinct(datos$department) > 1) {
      p <- p + facet_wrap(~department, ncol = ncol)
    }

    p +
      scale_fill_manual(values = col_etapas_pastel) +
      scale_color_manual(values = c("Total Nacional" = col_total)) +
      escala_anios(by = 20) +
      escala_fecundidad() +
      marcas_planificacion() +
      # Tres leyendas apiladas: etapas, línea nacional, nivel de reemplazo
      guides(fill     = guide_legend(nrow = 1, order = 1),
             color    = guide_legend(nrow = 1, order = 2),
             linetype = guide_legend(nrow = 1, order = 3)) +
      labs(x = "Año", y = "TFR", title = titulo) +
      theme_fecundidad(base_size = 11)
  }

  if (!is.null(Desc_dpto)) {

    guardar("TFR_departamental_1958_2018.png",
            fig_tfr_area(Desc_dpto,
                         "Tasa de Fecundidad Total por departamento"),
            ancho = 14, alto = 10)

    # Una figura por departamento
    for (dept in sort(unique(na.omit(Desc_dpto$department)))) {
      guardar(sprintf("TFR_%s_vs_National.png", gsub(" ", "_", dept)),
              fig_tfr_area(Desc_dpto %>% filter(department == dept), dept),
              carpeta = dir_graf_tfr_dpto, ancho = 9, alto = 5.5)
    }

    # Una figura por región, con un panel por departamento
    por_region(Desc_dpto, function(datos_reg, reg, archivo) {
      n_paneles <- n_distinct(datos_reg$department)
      ncol <- min(3, n_paneles)
      nrow <- ceiling(n_paneles / ncol)
      guardar(sprintf("TFR_%s.png", archivo),
              fig_tfr_area(datos_reg, reg, ncol = ncol),
              carpeta = dir_graf_tfr_reg,
              ancho = 3.5 * ncol + 1.5, alto = 3.3 * nrow + 1.5)
    })

  } else {

    message("Falta Indicadores_ASFR.xlsx (script 08): ",
            "el TFR departamental sale como líneas, sin descomposición.")

    p_panel <- tfr_dpto_plot %>%
      ggplot(aes(x = year, y = tfr)) +
      geom_line(linewidth = 0.4, color = col_series(1)) +
      facet_wrap(~department) +
      escala_anios(by = 20) +
      escala_fecundidad() +
      marcas_planificacion() +
      labs(x = "Año", y = "TFR",
           title = "Tasa de Fecundidad Total por departamento") +
      theme_fecundidad(base_size = 11)

    guardar("TFR_departamental_1958_2018.png", p_panel, ancho = 14, alto = 10)

    figuras_por_unidad(
      tfr_dpto_plot, tfr_nacional_ref, "department", "tfr", "year",
      "Año", "TFR", "TFR_%s_vs_National.png", dir_graf_tfr_dpto,
      escala = list(escala_anios(), escala_fecundidad(),
                    marcas_planificacion())
    )

    figuras_por_region(
      tfr_dpto_plot, tfr_nacional_ref, "tfr", "year",
      "Año", "TFR", "TFR_%s.png", dir_graf_tfr_reg,
      escala = list(escala_anios(by = 20), escala_fecundidad(),
                    marcas_planificacion())
    )
  }
}

# =====================================================================
# FECUNDIDAD COHORTAL COMPLETADA (scripts 05 y 06)
#
# La serie combina los censos IPUMS, que llegan hasta la cohorte 1955,
# con el CNPV 2018, que la extiende hasta 1966. Como el censo 2018
# reporta la edad en grupos quinquenales, sus cohortes van de cinco en
# cinco: en las figuras se ven como puntos espaciados al final de la
# serie.
# =====================================================================
archivo_fcc      <- "Fecundidad_Cohortal_Completada_IPUMS.xlsx"
archivo_fcc_2018 <- "Fecundidad_Cohortal_Completada_2018.xlsx"

FCC_DEPARTAMENTAL <- leer_tabla(archivo_fcc, "FCC_Departamental")
FCC_NACIONAL      <- leer_tabla(archivo_fcc, "FCC_Nacional")

FCC_DPTO_2018 <- leer_tabla(archivo_fcc_2018, "Departamental")
FCC_NAC_2018  <- leer_tabla(archivo_fcc_2018, "Nacional")

unir_fcc <- function(ipums, dane, vars_grupo) {
  unir_fuentes(ipums, dane, vars_grupo,
               c("cohort", "fcc_all", "fcc_cond"))
}

# Infecundidad definitiva: entre las mujeres de fecundidad ya completada
# (50 años o más), la proporción que nunca tuvo hijos. Sale de las
# mismas tablas de FCC: 'women' son todas y 'mothers' las que tuvieron
# al menos un hijo.
#
# La variante restringida a las alguna vez casadas o unidas está
# comentada en tres puntos (aquí, en suavizar_sin_hijos y en la llamada
# a figuras_sin_hijos): necesita women_cas y mothers_cas, que solo
# aparecen al volver a correr 05 y 06. Busca "_cas" para reactivarla.
sin_hijos_cohorte <- function(ipums, dane, vars_grupo) {
  unir_fuentes(ipums, dane, vars_grupo,
               c("cohort", "women", "mothers", "women_cas", "mothers_cas")) %>%
    mutate(
      pct_sin_hijos     = if_else(women > 0,
                                  100 * (women - mothers) / women,
                                  NA_real_)
                                  ,
      pct_sin_hijos_cas = if_else(women_cas > 0,
                                  100 * (women_cas - mothers_cas) / women_cas,
                                  NA_real_)
    ) %>%
    filter(!is.na(pct_sin_hijos))
}

# En cohortes con pocas mujeres el porcentaje sin hijos salta e incluso
# llega a cero, no porque no haya mujeres sin hijos sino por falta de
# observaciones. Por eso se suaviza con una media móvil.
#
# La suavización se aplica solo a los censos IPUMS, que dan una cohorte
# por año. El CNPV 2018 aporta cohortes de cinco en cinco: promediar
# cinco de ellas abarcaría veinticinco años de cohortes, así que sus
# valores se dejan tal cual y se muestran como puntos aparte.
suavizar_sin_hijos <- function(df, vars_grupo, ventana = 5) {
  if (is.null(df)) return(NULL)
  df %>%
    arrange(across(all_of(c(vars_grupo, "cohort")))) %>%
    group_by(across(all_of(c(vars_grupo, "fuente")))) %>%
    mutate(
      pct_suave = if (first(fuente) == "Censos IPUMS") {
        media_movil(pct_sin_hijos, ventana)
      } else {
        pct_sin_hijos
      }
      ,
      pct_suave_cas = if (first(fuente) == "Censos IPUMS") {
        media_movil(pct_sin_hijos_cas, ventana)
      } else {
        pct_sin_hijos_cas
      }
    ) %>%
    ungroup()
}

SinHijos_coh_nac  <- sin_hijos_cohorte(FCC_NACIONAL, FCC_NAC_2018,
                                       character(0)) %>%
  suavizar_sin_hijos(character(0))

SinHijos_coh_dpto <- sin_hijos_cohorte(FCC_DEPARTAMENTAL, FCC_DPTO_2018,
                                       "department") %>%
  suavizar_sin_hijos("department")

FCC_NACIONAL      <- unir_fcc(FCC_NACIONAL, FCC_NAC_2018, character(0))
FCC_DEPARTAMENTAL <- unir_fcc(FCC_DEPARTAMENTAL, FCC_DPTO_2018, "department")

# Las cohortes anteriores a 1920 se estiman con muy pocas mujeres, así
# que las figuras arrancan en 1920
cohorte_inicial <- 1920

# Recorta al rango de cohortes y descarta filas sin valor: si se dejaran,
# las figuras las eliminarían con un aviso y podrían vaciar un panel
recortar_cohortes <- function(df, columnas) {
  if (is.null(df)) return(NULL)
  df %>%
    filter(cohort >= cohorte_inicial) %>%
    filter(if_all(all_of(columnas), is.finite))
}

FCC_NACIONAL      <- recortar_cohortes(FCC_NACIONAL, c("fcc_all", "fcc_cond"))
FCC_DEPARTAMENTAL <- recortar_cohortes(FCC_DEPARTAMENTAL,
                                       c("fcc_all", "fcc_cond"))
SinHijos_coh_nac  <- recortar_cohortes(SinHijos_coh_nac, "pct_sin_hijos")
SinHijos_coh_dpto <- recortar_cohortes(SinHijos_coh_dpto, "pct_sin_hijos")

if (!is.null(FCC_NACIONAL)) {

  p_fcc_nac <- FCC_NACIONAL %>%
    select(cohort, fcc_all, fcc_cond) %>%
    pivot_longer(c(fcc_all, fcc_cond),
                 names_to = "serie", values_to = "valor") %>%
    mutate(serie = recode(serie,
                          fcc_all  = "Todas las mujeres",
                          fcc_cond = "Condicional (madres)")) %>%
    ggplot(aes(x = cohort, y = valor, color = serie)) +
    geom_line(linewidth = 1) +
    geom_point(size = 1.6) +
    scale_color_manual(values = c("Todas las mujeres"    = col_dpto,
                                  "Condicional (madres)" = col_total)) +
    escala_fecundidad() +
    marca_cohorte() +
    labs(x = "Cohorte de nacimiento", y = "FCC (hijos por mujer)",
         title = "Fecundidad Cohortal Completada – Colombia") +
    theme_fecundidad()

  guardar("FCC_nacional_cohortes.png", p_fcc_nac)
}

# Una figura por departamento, con el total nacional de referencia
if (!is.null(FCC_DEPARTAMENTAL) && !is.null(FCC_NACIONAL)) {

  figuras_por_unidad(
    FCC_DEPARTAMENTAL, FCC_NACIONAL, "department", "fcc_all", "cohort",
    "Cohorte de nacimiento", "FCC (hijos por mujer)",
    "FCC_%s_vs_National.png", dir_graf_fcc_dpto,
    escala = list(escala_fecundidad(), marca_cohorte())
  )

  # FCC condicional a haber sido madre
  figuras_por_unidad(
    FCC_DEPARTAMENTAL, FCC_NACIONAL, "department", "fcc_cond", "cohort",
    "Cohorte de nacimiento", "FCC condicional (madres)",
    "FCC_cond_%s_vs_National.png", dir_graf_fcc_dpto,
    escala = list(escala_fecundidad(), marca_cohorte())
  )

  # Una figura por región, con un panel por departamento
  figuras_por_region(
    FCC_DEPARTAMENTAL, FCC_NACIONAL, "fcc_all", "cohort",
    "Cohorte de nacimiento", "FCC (hijos por mujer)",
    "FCC_%s.png", dir_graf_fcc_reg,
    escala = list(escala_fecundidad(), marca_cohorte())
  )

  figuras_por_region(
    FCC_DEPARTAMENTAL, FCC_NACIONAL, "fcc_cond", "cohort",
    "Cohorte de nacimiento", "FCC condicional (madres)",
    "FCC_cond_%s.png", dir_graf_fcc_reg,
    escala = list(escala_fecundidad(), marca_cohorte())
  )
}

# =====================================================================
# INFECUNDIDAD DEFINITIVA POR COHORTE (scripts 05 y 06)
#
# Entre mujeres que ya completaron su vida fértil, la proporción que
# nunca tuvo hijos. A diferencia del % sin hijos de 15 a 54 años, aquí
# no se mezclan mujeres que todavía pueden tener hijos.
# =====================================================================

# Eje vertical común a todas las figuras de infecundidad, para que sean
# comparables entre departamentos y entre regiones
escala_sin_hijos <- function(limites = c(0, 25), by = 5) {
  list(
    scale_y_continuous(breaks = seq(limites[1], limites[2], by = by)),
    coord_cartesian(ylim = limites)
  )
}

if (!is.null(SinHijos_coh_dpto) && !is.null(SinHijos_coh_nac)) {

  # Genera las tres figuras de infecundidad (panel departamental, una por
  # departamento y una por region) a partir de una columna de porcentaje.
  # Se llama dos veces: para TODAS las mujeres y para las ALGUNA VEZ
  # CASADAS O UNIDAS. 'sufijo' distingue los archivos (los de "todas"
  # conservan el nombre de antes) y 'subtitulo' anota el grupo en el titulo.
  figuras_sin_hijos <- function(col, sufijo, subtitulo) {

    p_panel <- ggplot(SinHijos_coh_dpto, aes(x = cohort, y = .data[[col]])) +
      geom_line(color = col_dpto, linewidth = 0.7) +
      facet_wrap(~department) +
      escala_sin_hijos() +
      labs(x = "Cohorte de nacimiento", y = "% que nunca tuvo hijos",
           title = paste0(
             "Infecundidad definitiva por cohorte y departamento", subtitulo)) +
      theme_fecundidad(base_size = 11)

    guardar(sprintf("SinHijos_cohortal%s_panel.png", sufijo), p_panel,
            ancho = 14, alto = 10)

    # Una figura por departamento, contra el total nacional
    figuras_por_unidad(
      SinHijos_coh_dpto, SinHijos_coh_nac, "department", col, "cohort",
      "Cohorte de nacimiento", "% que nunca tuvo hijos",
      sprintf("SinHijos_cohortal%s_%%s.png", sufijo), dir_graf_sin_hijos,
      escala = escala_sin_hijos(), puntos = FALSE
    )

    # Una figura por region, con un panel por departamento
    figuras_por_region(
      SinHijos_coh_dpto, SinHijos_coh_nac, col, "cohort",
      "Cohorte de nacimiento", "% que nunca tuvo hijos",
      sprintf("SinHijos_cohortal%s_%%s.png", sufijo), dir_graf_sin_hijos_reg,
      escala = escala_sin_hijos()
    )
  }

  # Todas las mujeres (archivos como antes) y solo casadas o unidas
  figuras_sin_hijos("pct_suave",     "",         " (todas las mujeres)")
  figuras_sin_hijos("pct_suave_cas", "_casadas", " (alguna vez casada o unida)")
}

cat("\nFiguras generadas:", figuras_ok, "\n")

if (length(figuras_error) > 0) {
  cat("Figuras con error:", length(figuras_error), "\n")
  for (e in figuras_error) cat(" - ", e, "\n")
}

cat("\nArchivos por carpeta:\n")
for (d in c(dir_graf_resumen,
            dir_graf_tfr_dpto, dir_graf_tfr_reg,
            dir_graf_fcc_dpto, dir_graf_fcc_reg,
            dir_graf_sin_hijos, dir_graf_sin_hijos_reg)) {
  cat(sprintf("  %-55s %d\n", d, length(list.files(d, pattern = "\\.png$"))))
}

clean_session()
