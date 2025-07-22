#!/usr/bin/env python3
# pipeline_report.py

import re
import csv
import time
import sys
import os
import subprocess

import pandas as pd
import matplotlib.pyplot as plt
from Bio import Entrez, Phylo

# ——————————————————————————————————————————
# CONFIGURACIÓN Entrez
# ——————————————————————————————————————————
Entrez.email = "tu_email@ejemplo.com"

def open_file(path):
    """Abre un archivo con el programa por defecto."""
    if sys.platform.startswith("linux"):
        subprocess.run(["xdg-open", path])
    elif sys.platform == "darwin":
        subprocess.run(["open", path])
    elif os.name == "nt":
        os.startfile(path)

def get_species_name(accession):
    """
    Consulta NCBI por la accession y devuelve
    el nombre del organismo con espacios → guiones bajos.
    """
    try:
        handle = Entrez.efetch(db="nuccore", id=accession, retmode="xml")
        rec = Entrez.read(handle)
        org = rec[0]["GBSeq_organism"]
        return org.replace(" ", "_")
    except Exception as e:
        print(f"⚠️ Error con {accession}: {e}")
        return "Unknown"

def rename_tree_leaves(tree_nwk):
    """
    Usa tu lógica original de regex + rename_match para generar
    tree_fixed_renombrado.nwk y devuelve su ruta.
    """
    text = open(tree_nwk).read()
    pattern = re.compile(r'((?:barcode\d+\s+)?)NZ[ _]?([A-Z0-9.]+)(\s+\d+)?')
    matches = pattern.findall(text)
    accessions = sorted({ f"NZ_{m[1]}" for m in matches })

    acc2sp = {}
    for i, acc in enumerate(accessions, 1):
        sp = get_species_name(acc)
        acc2sp[acc] = sp
        print(f"✅ ({i}/{len(accessions)}) {acc} ➜ {sp}")
        time.sleep(0.34)

    def rename_match(m):
        bc   = m.group(1).strip()
        core = m.group(2)
        ident= m.group(3).strip() if m.group(3) else ""
        acc  = f"NZ_{core}"
        sp   = acc2sp.get(acc, acc)
        lbl  = f"{bc}_{sp}" if bc else sp
        if ident:
            lbl += f"_{ident}"
        return lbl

    renamed = pattern.sub(rename_match, text)
    out_nwk = tree_nwk.replace(".nwk", "_renombrado.nwk")
    with open(out_nwk, "w") as f:
        f.write(renamed)
    print(f"🌳 Árbol renombrado guardado en: {out_nwk}")
    return out_nwk

def process_blast_and_csv(blast_tsv, output_dir):
    """
    Lee blast_results.tsv, toma la mejor pident por barcode,
    consulta Entrez por cada ref, construye la columna Label
    y genera summary_full.csv con Barcode,Label,ref,pident,...
    """
    if not os.path.exists(blast_tsv):
        print(f"❌ No encuentro {blast_tsv}")
        sys.exit(1)

    df = pd.read_csv(
        blast_tsv, sep="\t", header=None,
        names=["qseqid","ref","pident","length","evalue","bitscore"]
    )
    df["Barcode"] = df["qseqid"].str.split("__").str[0]
    # quedarnos con la fila de mayor pident por Barcode
    df = (
        df
        .sort_values("pident", ascending=False)
        .drop_duplicates("Barcode", keep="first")
        .reset_index(drop=True)
    )

    # consultar la especie para cada accession
    df["Species"] = df["ref"].apply(get_species_name)

    # función para construir el Label idéntico al rename_match
    def rename_label(row):
        bc    = row["Barcode"]
        sp    = row["Species"]
        pct   = row["pident"]
        # formatear a 2 decimales sin signo %
        pct_s = f"{pct:.2f}"
        return f"{bc}_{sp}_{pct_s}"

    df["Label"] = df.apply(rename_label, axis=1)

    # grabar sólo las columnas deseadas, con Label como segunda col
    summary_csv = os.path.join(output_dir, "summary_full.csv")
    df.to_csv(
        summary_csv,
        index=False,
        columns=["Barcode","Label","ref","pident","length","evalue","bitscore"]
    )
    print(f"🗒️ Summary completo: {summary_csv}")
    open_file(summary_csv)
    return df

def plot_tree(tree_nwk):
    """Dibuja el árbol Newick con Matplotlib y abre el PNG."""
    tree = Phylo.read(tree_nwk, "newick")
    fig, ax = plt.subplots(figsize=(14,8))
    Phylo.draw(
        tree,
        axes=ax,
        do_show=False,
        label_func=lambda c: c.name if c.is_terminal() else None
    )
    ax.set_axis_off()
    out_png = tree_nwk.replace(".nwk","_plot.png")
    plt.savefig(out_png, dpi=300, bbox_inches="tight")
    print(f"🖼️ Árbol dibujado en: {out_png}")
    open_file(out_png)

def plot_identity(df, output_dir):
    """Genera un bar‐plot de % identity y abre el PNG."""
    if df.empty or df["pident"].dropna().empty:
        print("⚠️ No hay datos de identidad para graficar.")
        return
    fig, ax = plt.subplots(figsize=(10,4))
    df.set_index("Barcode")["pident"].plot.bar(ax=ax)
    ax.set_ylabel("% identity")
    ax.set_xlabel("")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    out = os.path.join(output_dir, "identity_barplot.png")
    plt.savefig(out, dpi=300)
    print(f"🖼️ Barplot identidad: {out}")
    open_file(out)

def main():
    if len(sys.argv) != 2:
        print("Uso: python pipeline_report.py <ruta/tree_fixed.nwk>")
        sys.exit(1)

    tree_fixed = sys.argv[1]
    output_dir = os.path.dirname(tree_fixed)
    blast_tsv  = os.path.join(output_dir, "blast_results.tsv")

    # 1) Renombrar el árbol usando tu lógica original
    tree_r = rename_tree_leaves(tree_fixed)

    # 2) Procesar BLAST y generar summary_full.csv con Labels
    df_summary = process_blast_and_csv(blast_tsv, output_dir)

    # 3) Dibujar el árbol renombrado
    plot_tree(tree_r)

    # 4) Graficar % identity
    plot_identity(df_summary, output_dir)

if __name__ == "__main__":
    main()
