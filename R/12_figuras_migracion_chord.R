# =====================================================================
# 12_figuras_migracion_chord.R — Diagramas de cuerdas de migración
# Proyecto: Demografía CEER 30 años
#
# Adapta 14_code_mig_flows_2019.R (Karina Acosta, 2024), que produce las
# figuras 3 y 4 de Acosta y Gu (2022, DTSERU 304), a los flujos que
# genera R/11_flujos_migracion_geih.R para 2012, 2019, 2022 y 2024.
#
# Cambios frente al código original:
#  - Los colores se asignan por nombre de departamento, no por posición,
#    para que cada departamento conserve su color en todos los años.
#  - La versión regional ordena los sectores por región (Caribe, Andina
#    central, Andina oriental, Pacífica, Orinoquía y Amazonía) y colorea
#    cada departamento con el color de su región.
#  - Se guarda con png() (ggsave no captura gráficos base de circlize).
#
# Salidas en output/graficas/migracion/:
#   chord_{5y|1y}_{año}.png            un color por departamento
#   chord_{5y|1y}_{año}_regiones.png   un color por región
#   chord_5y_panel.png                 los cuatro años lado a lado
# =====================================================================

if (!exists("data_dir")) source("R/00_setup.R")
if (requireNamespace("pacman", quietly = TRUE)) pacman::p_load(circlize, data.table) else {
  library(circlize); library(data.table)
}

dir_tab_mig  <- file.path(output_dir, "tablas", "migracion")
dir_graf_mig <- file.path(output_dir, "graficas", "migracion")
dir.create(dir_graf_mig, showWarnings = FALSE, recursive = TRUE)

# Paleta del código original, un color por departamento (en el orden de
# flows_5y_2019.csv)
orden_dptos <- c("Antioquia", "Atlantico", "Bogota", "Bolivar", "Boyaca",
                 "Caldas", "Caque", "Cauca", "Cesar", "Cordoba",
                 "Cundinamarca", "Choco", "Huila", "Guaj", "Magd", "Meta",
                 "Narino", "NS", "Quind", "Risaral", "Santand", "Sucre",
                 "Tolima", "Valle")
col_dptos <- setNames(c(
  "#228B8DFF", "#8AD647FF", "#8E0152", "#E2E418FF", "#482071FF", "#34618DFF",
  "#8DD3C7", "#FFFFB3", "#BEBADA", "#FB8072", "#80B1D3", "#FDB462",
  "#B3DE69", "#FCCDE5", "#D9D9D9", "#BC80BD", "#CCEBC5", "#FFED6F",
  "#7FBC41", "#2A768EFF", "#C51B7D", "#1B9E77", "#D95F02", "#7570B3"),
  orden_dptos)

# Regiones (ver R/11_flujos_migracion_geih.R) y sus colores, tomados de
# la paleta regional del código original
region_corto <- c(
  Atlantico = "Caribe", Bolivar = "Caribe", Cesar = "Caribe",
  Cordoba = "Caribe", Guaj = "Caribe", Magd = "Caribe", Sucre = "Caribe",
  Antioquia = "Andina central", Caldas = "Andina central",
  Huila = "Andina central", Quind = "Andina central",
  Risaral = "Andina central", Tolima = "Andina central",
  Bogota = "Andina oriental", Boyaca = "Andina oriental",
  Cundinamarca = "Andina oriental", NS = "Andina oriental",
  Santand = "Andina oriental",
  Cauca = "Pacífica", Choco = "Pacífica", Narino = "Pacífica",
  Valle = "Pacífica",
  Caque = "Orinoquía y Amazonía", Meta = "Orinoquía y Amazonía")
col_regiones <- c("Caribe" = "#E2E418FF", "Andina central" = "#228B8DFF",
                  "Andina oriental" = "#8E0152", "Pacífica" = "#8AD647FF",
                  "Orinoquía y Amazonía" = "#D95F02")
orden_regional <- names(region_corto)[order(match(region_corto, names(col_regiones)))]

# Lee flows_{h}_{año}.csv y deja origen, destino y valor (como el
# original: mig[-c(1:2)])
leer_flujos <- function(h, anio) {
  f <- file.path(dir_tab_mig, sprintf("flows_%s_%s.csv", h, anio))
  if (!file.exists(f)) return(NULL)
  as.data.frame(fread(f)[, .(out_dpto, in_dpto, val)])
}

# Diagrama con los parámetros del código original
chord <- function(mig, titulo, regional = FALSE, cex_nombres = 0.7) {
  orden <- if (regional) orden_regional else orden_dptos
  colores <- if (regional) col_regiones[region_corto[orden]] else col_dptos[orden]
  names(colores) <- orden

  circos.clear()
  circos.par(start.degree = 90, gap.degree = 4,
             track.margin = c(-0.1, 0.1), points.overflow.warning = FALSE)
  par(mar = rep(0, 4))

  chordDiagram(
    x = mig,
    order = orden,
    grid.col = colores,
    transparency = 0.25,
    directional = 1,
    direction.type = c("arrows", "diffHeight"),
    diffHeight = -0.04,
    annotationTrack = "grid",
    annotationTrackHeight = c(0.05, 0.1),
    link.arr.type = "big.arrow",
    link.sort = TRUE,
    link.largest.ontop = TRUE)

  circos.trackPlotRegion(
    track.index = 1,
    bg.border = NA,
    panel.fun = function(x, y) {
      xlim <- get.cell.meta.data("xlim")
      sector.index <- get.cell.meta.data("sector.index")
      circos.text(x = mean(xlim), y = 2.1, labels = sector.index,
                  facing = "bending", cex = cex_nombres)
    })

  text(0, 1.05,"", cex = 0.9, font = 2)

  if (regional) {
    legend("bottomleft", legend = names(col_regiones), fill = col_regiones,
           border = NA, bty = "n", cex = 0.7)
  }
  circos.clear()
}

etiqueta_h <- c("5y" = "Five-years migration flows", "1y" = "One-year migration flows")
anios <- sort(as.integer(unique(sub("flows_[15]y_(\\d{4})\\.csv", "\\1",
  list.files(dir_tab_mig, pattern = "^flows_[15]y_\\d{4}\\.csv$")))))

# ---------------------------------------------------------------------
# 1. UN DIAGRAMA POR AÑO, HORIZONTE Y PALETA
# ---------------------------------------------------------------------
for (h in c("5y", "1y")) {
  for (a in anios) {
    mig <- leer_flujos(h, a)
    if (is.null(mig)) next
    for (regional in c(FALSE, TRUE)) {
      archivo <- file.path(dir_graf_mig, sprintf("chord_%s_%s%s.png", h, a,
                                                 if (regional) "_regiones" else ""))
      png(archivo, width = 8, height = 8, units = "in", res = 300)
      chord(mig, sprintf("%s, %s", etiqueta_h[h], a), regional = regional)
      dev.off()
      cat("Guardado:", archivo, "\n")
    }
  }
}

# ---------------------------------------------------------------------
# 2. PANEL CON TODOS LOS AÑOS (5 AÑOS), COMO LA FIGURA 4 DEL DOCUMENTO
# ---------------------------------------------------------------------
anios_5y <- anios[file.exists(file.path(dir_tab_mig, sprintf("flows_5y_%s.csv", anios)))]
if (length(anios_5y) > 1) for (regional in c(FALSE, TRUE)) {
  archivo <- file.path(dir_graf_mig, sprintf("chord_5y_panel%s.png",
                                             if (regional) "_regiones" else ""))
  png(archivo, width = 6 * length(anios_5y), height = 6.3, units = "in", res = 300)
  layout(matrix(seq_along(anios_5y), nrow = 1))
  for (a in anios_5y) chord(leer_flujos("5y", a), as.character(a),
                         regional = regional, cex_nombres = 0.6)
  dev.off()
  cat("Guardado:", archivo, "\n")
}

if (exists("clean_session")) clean_session()
