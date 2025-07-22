# Pipeline de Secuenciación y Filogenia de gyrA

Este repositorio proporciona una **pipeline** completa para:

1. Procesar lecturas Nanopore por código de barras (`barcode*`) y generar secuencias de consenso.  
2. Asignar taxonomía mediante **BLAST**.  
3. Alinear las secuencias de consenso con **MAFFT** y construir un árbol filogenético con **FastTree**.  
4. Renombrar cada hoja del árbol con su nombre de especie y porcentaje de identidad.  
5. Generar un CSV resumen, una figura del árbol y un gráfico de barras de identidad.  
6. Abrir automáticamente todos los informes para una revisión rápida.

---

## 📂 Estructura del repositorio

- **`analisis_seq.sh`**  
  Script Bash que:
  - Concatena lecturas por barcode  
  - Selecciona la lectura más larga como referencia temporal  
  - Realiza alineamiento con **minimap2** + **samtools**  
  - Llama consensos con **medaka**  
  - Construye y consulta base BLAST  
  - Genera `replacements.tsv` (barcode → `barcode__especie__identidad%`)  
  - Alinea consensos con **MAFFT**  
  - Construye árbol con **FastTree** (`tree_fixed.nwk`)

- **`pipeline_report.py`**  
  Script Python que:
  1. Renombra las hojas de `tree_fixed.nwk` consultando NCBI (**Entrez**)  
     y aplicando la lógica de **regex** original.  
  2. Procesa `blast_results.tsv`, selecciona la mejor identidad por barcode  
     y genera `summary_full.csv` con una columna `Label` igual al nombre en el árbol.  
  3. Dibuja el árbol renombrado (`tree_fixed_plot.png`).  
  4. Grafica el `% identity` por barcode (`identity_barplot.png`).  
  5. Abre automáticamente el CSV y las figuras.

- **`requirements.txt`**  
  Dependencias Python:
  ```
  biopython
  pandas
  matplotlib
  ```

---

## ⚙️ Prerrequisitos

- **Linux/macOS** (o Windows con ajustes en `open_file()`)  
- **Python 3.8+** (`pip install -r requirements.txt`)  
- **Email válido** para NCBI Entrez (configurar en el script)  
- Herramientas en `$PATH`: `medaka`, `minimap2`, `samtools`, `seqkit`, `mafft`, `FastTree`, `blast+`

---

## 🚀 Uso Rápido

1. **Clonar** el repositorio:
   ```bash
   git clone https://github.com/tu_usuario/gyrA‑phylo‑pipeline.git
   cd gyrA‑phylo‑pipeline
   ```

2. **Ejecutar** el pipeline Bash:
   ```bash
   chmod +x analisis_seq.sh
   bash analisis_seq.sh /ruta/a/tu/carpeta_de_lecturas
   ```
   Esto genera en `pipeline_output/`:
   - `tree_fixed.nwk`  
   - `blast_results.tsv`  
   - `replacements.tsv`  
   - directorios de consensos, alineamientos, BAMs, etc.

3. **Instalar** dependencias Python:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

4. **Generar reporte**:
   ```bash
   python pipeline_report.py pipeline_output/tree_fixed.nwk
   ```
   Verás en `pipeline_output/`:
   - `tree_fixed_renombrado.nwk`  
   - `summary_full.csv`  
   - `tree_fixed_plot.png`  
   - `identity_barplot.png`  
   Y cada archivo se abrirá automáticamente.

---

## 🤝 Contribuciones

1. **Fork** del repositorio y crea un branch.  
2. Realiza cambios y añade tests o ejemplos.  
3. Envía un **Pull Request** describiendo tus mejoras.

---

## 📜 Licencia

Este proyecto está licenciado bajo **MIT License**.  
