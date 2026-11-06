"""
figuras_metodologia.py: figuras de DECISIONES_METODOLOGICAS.md

Lee las tablas que ya producen los scripts de R/ (output/tablas/) y guarda
las figuras en Documento/metodologia/. No procesa microdatos.

Desde la raíz del repositorio:
    python Documento/metodologia/figuras_metodologia.py
Requiere pandas, openpyxl y matplotlib.
"""
from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker
from matplotlib.lines import Line2D

RAIZ = Path(__file__).resolve().parents[2]
OUT = next(p for p in (RAIZ / "output", RAIZ / "Output") if p.exists())
TAB = OUT / "tablas"
FIG = Path(__file__).resolve().parent

# Paleta categórica (orden fijo) y tintas
C = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"]
INK, INK2, GRID = "#0b0b0b", "#52514e", "#e4e3df"

plt.rcParams.update({
    "font.size": 10, "axes.edgecolor": INK2, "axes.labelcolor": INK2,
    "xtick.color": INK2, "ytick.color": INK2, "axes.spines.top": False,
    "axes.spines.right": False, "axes.grid": True, "grid.color": GRID,
    "grid.linewidth": 0.6, "axes.axisbelow": True, "legend.frameon": False,
    "axes.titleweight": "bold", "axes.titlesize": 11, "axes.titlecolor": INK,
})

def es(x, dec=0):
    """Número con formato en español: punto de miles y coma decimal."""
    t = f"{x:,.{dec}f}"
    return t.replace(",", "X").replace(".", ",").replace("X", ".")

def eje_es(ax, eje="y"):
    fmt = matplotlib.ticker.FuncFormatter(lambda v, _: es(v))
    (ax.yaxis if eje == "y" else ax.xaxis).set_major_formatter(fmt)

def guardar(fig, nombre):
    fig.savefig(FIG / nombre, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("Guardado:", FIG / nombre)

# ---------------------------------------------------------------------
# 1. Traslape de las ventanas retrospectivas entre censos
# ---------------------------------------------------------------------
por_censo = pd.read_excel(TAB / "TFR_nacional_1958_2005.xlsx", sheet_name="TFR_por_censo")
agregado = pd.read_excel(TAB / "TFR_nacional_1958_2005.xlsx", sheet_name="TFR")
censos = sorted(por_censo.census_year.unique())

fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 6.2), sharex=True,
                             gridspec_kw={"height_ratios": [1, 2.4], "hspace": 0.12})
for i, c in enumerate(censos):
    d = por_censo[por_censo.census_year == c]
    a1.barh(i, d.year.max() - d.year.min() + 1, left=d.year.min() - 0.5,
            height=0.55, color=C[i], edgecolor="white", linewidth=2)
    a1.text(d.year.max() + 1.2, i, f"Censo {c}: {d.year.min()}–{d.year.max()}",
            va="center", fontsize=9, color=INK2)
# años cubiertos por más de un censo
cuenta = por_censo.groupby("year").census_year.nunique()
for y in cuenta[cuenta > 1].index:
    for a in (a1, a2):
        a.axvspan(y - 0.5, y + 0.5, color="#d9d8d3", alpha=0.45, lw=0, zorder=0)
a1.set_yticks([]); a1.invert_yaxis(); a1.grid(False)
a1.spines["left"].set_visible(False)
a1.set_title("Cada censo aporta 15 años de tasas retrospectivas y las ventanas se traslapan",
             loc="left")

for i, c in enumerate(censos):
    d = por_censo[por_censo.census_year == c]
    a2.fill_between(d.year, d.tfr_lower, d.tfr_upper, color=C[i], alpha=0.15, lw=0)
    a2.plot(d.year, d.tfr, color=C[i], lw=2, label=f"Censo {c}")
a2.plot(agregado.year, agregado.tfr, color=INK, lw=1.2, ls=(0, (3, 2)),
        label="Serie agregada (conteos sumados)")
a2.set_ylabel("TFR (hijos por mujer)")
a2.set_title("En los años traslapados los censos no coinciden: el más antiguo da valores más bajos al final de su ventana", loc="left", fontsize=9.5, fontweight="normal", color=INK2)
a2.set_xlabel("Año calendario")
a2.set_xlim(por_censo.year.min() - 1, por_censo.year.max() + 9)
a2.legend(loc="upper right", ncol=1, fontsize=9)
a2.text(0.01, 0.03, "Franjas grises: años cubiertos por dos censos. Banda: IC 95%.",
        transform=a2.transAxes, fontsize=8.5, color=INK2)
guardar(fig, "fig1_traslape_censos.png")

# ---------------------------------------------------------------------
# 2. Unión de fuentes: IPUMS y CNPV 2018 (TFR y FCC)
# ---------------------------------------------------------------------
tfr18 = pd.read_excel(TAB / "TFR_nacional_2018.xlsx", sheet_name="TFR")
fcc_ip = pd.read_excel(TAB / "Fecundidad_Cohortal_Completada_IPUMS.xlsx", sheet_name="FCC_Nacional")
fcc18 = pd.read_excel(TAB / "Fecundidad_Cohortal_Completada_2018.xlsx", sheet_name="Nacional")

fig, (b1, b2) = plt.subplots(1, 2, figsize=(10, 3.9))
b1.plot(agregado.year, agregado.tfr, color=C[0], lw=2, label="Censos IPUMS (edad simple)")
b1.plot(tfr18.year, tfr18.tfr, color=C[1], lw=0, marker="o", ms=7,
        markeredgecolor="white", mew=1.5, label="CNPV 2018 (quinquenal)")
b1.axhline(2.1, color=INK2, lw=0.9, ls=":")
b1.text(agregado.year.min(), 2.25, "Reemplazo (2,1)", fontsize=8.5, color=INK2)
b1.set_title("TFR por año calendario", loc="left")
b1.set_xlabel("Año"); b1.set_ylabel("Hijos por mujer"); b1.set_ylim(0, 8)

b2.plot(fcc_ip.cohort, fcc_ip.fcc_all, color=C[0], lw=2, label="Censos IPUMS (edad simple)")
b2.plot(fcc18.cohort, fcc18.fcc_all, color=C[1], lw=0, marker="o", ms=7,
        markeredgecolor="white", mew=1.5, label="CNPV 2018 (quinquenal)")
b2.axvline(1920, color=INK2, lw=0.9, ls=":")
b2.text(1921, 0.4, "cohorte_inicial = 1920", fontsize=8.5, color=INK2)
b2.set_title("FCC por cohorte de nacimiento", loc="left")
b2.set_xlabel("Cohorte"); b2.set_ylim(0, 8)
h, l = b1.get_legend_handles_labels()
fig.legend(h, l, loc="lower center", ncol=2, bbox_to_anchor=(0.5, -0.04))
fig.tight_layout(rect=(0, 0.06, 1, 1))
guardar(fig, "fig2_union_fuentes.png")

# ---------------------------------------------------------------------
# 3. Descomposición del TFR por etapa (nacional)
# ---------------------------------------------------------------------
desc = pd.read_excel(TAB / "Indicadores_ASFR.xlsx", sheet_name="Descomposicion_nacional")
etapas = list(dict.fromkeys(desc.etapa))
ancho = desc.pivot(index="year", columns="etapa", values="tfr_parcial")[etapas].fillna(0)
fig, ax = plt.subplots(figsize=(9, 3.9))
ax.stackplot(ancho.index, ancho.T.values, labels=etapas, colors=C[:len(etapas)],
             edgecolor="white", linewidth=0.8)
ax.axhline(2.1, color=INK, lw=0.9, ls=":")
ax.set_title("El alto del área apilada es el TFR: suma de las tasas por tramo de edad",
             loc="left")
ax.set_xlabel("Año"); ax.set_ylabel("Hijos por mujer")
ax.legend(loc="upper right", fontsize=9)
guardar(fig, "fig3_descomposicion_etapas.png")

# ---------------------------------------------------------------------
# 4. Réplica de migración 2019 contra Acosta y Gu
# ---------------------------------------------------------------------
rep = pd.read_csv(TAB / "migracion" / "replica_flows_5y_2019_vs_AcostaGu.csv")
fig, ax = plt.subplots(figsize=(5.6, 5.4))
lim = max(rep.val_AcostaGu.max(), rep.val_fex2011.max()) * 1.05
ax.plot([0, lim], [0, lim], color=INK2, lw=0.9, ls=":", label="45°")
ax.scatter(rep.val_AcostaGu, rep.val_fex2011, s=22, color=C[0], alpha=0.75,
           edgecolor="white", linewidth=0.6, label="Par origen-destino")
r = rep[["val_AcostaGu", "val_fex2011"]].corr().iloc[0, 1]
t0, t1 = rep.val_AcostaGu.sum(), rep.val_fex2011.sum()
ax.text(0.03, 0.97, f"Correlación: {es(r, 3)}\nTotal propio: {es(t1)} mil\n"
        f"Total Acosta y Gu: {es(t0)} mil\n"
        f"Pares con diferencia < 1 mil: {es(100 * ((rep.val_fex2011 - rep.val_AcostaGu).abs() < 1).mean())}%", transform=ax.transAxes, va="top",
        fontsize=9, color=INK)
ax.set_xlim(0, lim); ax.set_ylim(0, lim)
ax.set_xlabel("Acosta y Gu (miles)"); ax.set_ylabel("Réplica con fex_c_2011 (miles)")
ax.set_title("Réplica 2019, migración a 5 años", loc="left")
ax.legend(loc="lower right", fontsize=9)
guardar(fig, "fig4_replica_migracion_2019.png")

# ---------------------------------------------------------------------
# 5. Totales de migración por año, horizonte e instrumento
# ---------------------------------------------------------------------
filas = []
for a in (2012, 2019, 2022, 2024):
    for h in ("5y", "1y"):
        f = TAB / "migracion" / f"flows_{h}_{a}.csv"
        if f.exists():
            filas.append((a, h, pd.read_csv(f).val.sum()))
tot = pd.DataFrame(filas, columns=["anio", "h", "val"])
instr = {2012: "Módulo 2012\n(años en el municipio)", 2019: "Módulo 2019\n(residencia hace 5 años)",
         2022: "GEIH marco 2018", 2024: "GEIH marco 2018"}
fig, ax = plt.subplots(figsize=(8.5, 4))
x = range(len(instr)); w = 0.36
for j, (h, nom) in enumerate((("5y", "A 5 años"), ("1y", "A 1 año"))):
    d = tot[tot.h == h].set_index("anio").reindex(list(instr))
    pos = [i + (j - 0.5) * (w + 0.02) for i in x]
    ax.bar(pos, d.val, width=w, color=C[j], label=nom)
    for p, v in zip(pos, d.val):
        ax.text(p, v + 40, es(v), ha="center", fontsize=8.5, color=INK2)
ax.set_xticks(list(x)); ax.set_xticklabels([f"{a}\n{instr[a]}" for a in instr], fontsize=8.5)
ax.axvline(1.5, color=INK2, lw=0.9, ls=":")
ax.set_ylabel("Migrantes interdepartamentales (miles)")
ax.set_title("Totales con factor CNPV 2018, sistema cerrado de 24 departamentos", loc="left")
ax.legend(loc="upper right")
ax.grid(axis="x", visible=False)
eje_es(ax)
guardar(fig, "fig5_totales_migracion.png")
