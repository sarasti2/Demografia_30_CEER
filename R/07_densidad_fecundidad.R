# =====================================================================
# 07_densidad_fecundidad.R — Densidad poblacional y fecundidad
#
# Cruza la densidad de población de cada departamento en cada año censal
# con su TFR, para explorar si los departamentos más densos tienen menor
# fecundidad.
#
# La densidad viene de POPDENSGEO1 (IPUMS): personas por kilómetro
# cuadrado de la unidad GEOLEV1, con fronteras consistentes entre
# censos. Es una variable de hogar, constante dentro de cada
# departamento y año censal.
#
# Correrlo después de 02_asfr_tfr_departamental_ipums.R.
#
# Salida: output/graficas/resumen/Densidad_vs_TFR.png
# =====================================================================

source("R/00_setup.R")

# Ventana de años previos a cada censo con que se promedia el TFR, para
# reducir el ruido de las estimaciones anuales
ventana_tfr <- 5

# ---------------------------------------------------------------------
# 1. DENSIDAD POR DEPARTAMENTO Y AÑO CENSAL
# ---------------------------------------------------------------------
densidad <- prepare_ipums() %>%
  filter(!is.na(department)) %>%
  group_by(department, YEAR) %>%
  summarise(
    densidad  = mean(as.numeric(POPDENSGEO1), na.rm = TRUE),
    personas  = n(),
    .groups = "drop"
  )

rm(list = setdiff(ls(), c(setup_objects, "densidad", "ventana_tfr")))
gc(verbose = FALSE)

cat("Densidad (personas por km2) por año censal:\n")
densidad %>%
  group_by(YEAR) %>%
  summarise(min = min(densidad), mediana = median(densidad),
            max = max(densidad), .groups = "drop") %>%
  as.data.frame() %>%
  print(row.names = FALSE)

# ---------------------------------------------------------------------
# 2. TFR DEPARTAMENTAL EN CADA AÑO CENSAL
# ---------------------------------------------------------------------
tfr_dpto <- read_excel(
  file.path(dir_tablas, "TFR_departamental_1958_2005.xlsx"), sheet = "TFR")

# Para cada censo se toma el promedio de los años previos a la fecha del
# censo, que es el período que ese censo estima con más precisión
tfr_censo <- lapply(sort(unique(densidad$YEAR)), function(yr) {
  tfr_dpto %>%
    filter(year >= yr - ventana_tfr, year < yr) %>%
    group_by(department) %>%
    summarise(tfr = mean(tfr, na.rm = TRUE), .groups = "drop") %>%
    mutate(YEAR = yr)
}) %>%
  bind_rows()

panel <- densidad %>%
  inner_join(tfr_censo, by = c("department", "YEAR")) %>%
  mutate(log_densidad = log(densidad)) %>%
  filter(is.finite(log_densidad), is.finite(tfr))

# ---------------------------------------------------------------------
# 3. REGRESIÓN POR AÑO CENSAL
# ---------------------------------------------------------------------
# Pendiente (beta) y bondad de ajuste, para anotar cada panel
regresion_por_anio <- panel %>%
  group_by(YEAR) %>%
  group_modify(~ {
    ajuste <- lm(tfr ~ log_densidad, data = .x)
    resumen <- summary(ajuste)
    tibble(
      beta    = coef(ajuste)[["log_densidad"]],
      ee      = resumen$coefficients["log_densidad", "Std. Error"],
      valor_p = resumen$coefficients["log_densidad", "Pr(>|t|)"],
      r2      = resumen$r.squared,
      n       = nrow(.x)
    )
  }) %>%
  ungroup()

cat("\nRegresión de TFR sobre log(densidad), por año censal:\n")
print(as.data.frame(regresion_por_anio %>% mutate(across(where(is.numeric),
                                                         ~ round(.x, 3)))),
      row.names = FALSE)

# Etiquetas para anotar cada panel de la dispersión
etiquetas_regresion <- regresion_por_anio %>%
  mutate(etiqueta = sprintf("beta = %.2f\nR2 = %.2f", beta, r2))

cat("\nNota: son asociaciones descriptivas, no efectos causales.\n")

# ---------------------------------------------------------------------
# 4. GRAFICA: DISPERSIÓN POR AÑO CENSAL
# ---------------------------------------------------------------------
p_scatter <- panel %>%
  ggplot(aes(x = densidad, y = tfr)) +
  geom_point(color = col_dpto, size = 2, alpha = 0.8) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
              color = col_nacional, linetype = "dashed",
              linewidth = 0.8, fill = col_banda_fill) +
  geom_text(data = etiquetas_regresion,
            aes(x = Inf, y = Inf, label = etiqueta),
            hjust = 1.1, vjust = 1.2, size = 3.2, color = "grey20",
            inherit.aes = FALSE) +
  scale_x_log10() +
  facet_wrap(~YEAR) +
  labs(x = "Densidad de población (personas por km², escala log)",
       y = "TFR") +
  theme_fecundidad(base_size = 11)

ggsave(file.path(dir_graf_resumen, "Densidad_vs_TFR.png"),
       p_scatter, width = 11, height = 7, dpi = 300)

cat("\nResultados guardados en", dir_graf_resumen, "\n")

clean_session()
