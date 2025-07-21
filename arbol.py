# rename_tree_leaves_with_species_and_csv.py

import re
import csv
import time
from Bio import Entrez

Entrez.email = "tu_email@ejemplo.com"  # Reemplaza con tu correo

def get_species_name(accession):
    try:
        handle = Entrez.efetch(db="nuccore", id=accession, retmode="xml")
        record = Entrez.read(handle)
        organism = record[0]["GBSeq_organism"]
        return organism.replace(" ", "_")
    except Exception as e:
        print(f"⚠️ Error con {accession}: {e}")
        return "Unknown"

def main():
    tree_path = input("🧬 Ruta al archivo Newick (.nwk): ").strip()
    if not tree_path.endswith(".nwk"):
        print("❌ El archivo debe tener extensión .nwk")
        return

    output_tree = tree_path.replace(".nwk", "_renombrado.nwk")
    output_csv = tree_path.replace(".nwk", "_especies.csv")

    with open(tree_path, "r") as f:
        tree = f.read()

    # Captura: (barcode opcional)(accesión)(porcentaje identidad opcional)
    pattern = r'((?:barcode\d+\s+)?)' + r'(NZ_[A-Z0-9.]+)' + r'(\s+\d+)?'
    matches = re.findall(pattern, tree)

    # Accesiones únicas
    accessions = sorted(set(m[1] for m in matches))
    print(f"🔍 Encontradas {len(accessions)} accesiones únicas.")

    acc_to_species = {}
    csv_rows = []

    for i, acc in enumerate(accessions, 1):
        species = get_species_name(acc)
        acc_to_species[acc] = species

        # Obtener barcode desde el primer match que lo tenga
        barcode = next((m[0].strip() for m in matches if m[1] == acc and m[0].strip()), "")
        csv_rows.append([acc, species, barcode])
        print(f"✅ ({i}/{len(accessions)}) {acc} ➜ {species}")
        time.sleep(0.34)

    # Reemplazo en el árbol
    def rename_match(match):
        barcode = match[0].strip()
        acc = match[1]
        identity = match[2].strip() if match[2] else ""
        species = acc_to_species.get(acc, acc)
        new_name = f"{barcode}_{species}".strip("_")
        return f"{new_name} {identity}".strip()

    new_tree = re.sub(pattern, rename_match, tree)

    with open(output_tree, "w") as f:
        f.write(new_tree)

    with open(output_csv, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Accesion", "Especie", "Barcode"])
        writer.writerows(csv_rows)

    print(f"\n🌳 Árbol renombrado: {output_tree}")
    print(f"🧾 CSV resumen generado: {output_csv}")

if __name__ == "__main__":
    main()

