# Pipeline de Análisis de Secuencias y Generación de Árbol Filogenético

Este repositorio contiene dos scripts principales para el procesamiento y análisis de datos de secuenciación y la generación de un árbol filogenético:

- **analisis_seq.sh**: Pipeline en Bash para procesar lecturas de Nanopore de *Bacillus*, generar consensos, clasificar por BLAST, renombrar secuencias, alinear con MAFFT y construir un árbol filogenético con FastTree.
- **arbol.py**: Renombra las hojas de un árbol en formato Newick usando los nombres de organismos obtenidos desde NCBI y genera un CSV con el resumen de accesiones y especies.

---

## Archivos

### analisis_seq.sh

- **Descripción**:

  - Pipeline completo para analizar lecturas de Nanopore de *Bacillus*:
    1. Crea carpetas de salida (`pipeline_output`, `consensus`, `blast_db`).
    2. Construye base de datos BLAST a partir de `Bacillus_ref.fasta`.
    3. Para cada subdirectorio `barcode*/`:
       - Mapea lecturas con `minimap2`, ordena e indexa con `samtools`.
       - Genera consenso con `medaka_consensus`.
       - Renombra la cabecera de consenso a solo el `barcode` usando `seqkit`.
    4. Concatena todos los consensos en `all_consensus.fasta`.
    5. Clasifica cada consenso contra la base BLAST (`blastn`), guarda resultados en `blast_results.tsv`.
    6. Genera `replacements.tsv` con nombre limpio de especie y porcentaje de identidad.
    7. Aplica cambios a `all_consensus.fasta` → `all_consensus_fixed.fasta`.
    8. Alinea con `mafft` → `aligned_fixed.fasta`.
    9. Construye árbol filogenético con `FastTree` → `tree_fixed.nwk`.

- **Uso**:

  ```bash
  bash analisis_seq.sh /ruta/a/directorio
  ```

  - **Input requerido** en el directorio proporcionado:
    - `Bacillus_ref.fasta`: referencia de *Bacillus* para BLAST.
    - Subdirectorios `barcode1/`, `barcode2/`, … conteniendo archivos `.fastq.gz`.
  - **Salida** en `pipeline_output/`:
    - Carpeta `consensus/` con consensos por barcode.
    - Carpeta `blast_db/` con base BLAST.
    - Archivos intermedios y finales:
      - `all_consensus.fasta`, `all_consensus_fixed.fasta`
      - `aligned_fixed.fasta`
      - `tree_fixed.nwk`

- **Dependencias**:

  - `bash`
  - [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs) (`makeblastdb`, `blastn`)
  - [minimap2](https://github.com/lh3/minimap2)
  - [samtools](http://www.htslib.org/)
  - [medaka](https://github.com/nanoporetech/medaka)
  - [seqkit](https://bioinf.shenwei.me/seqkit/)
  - [MAFFT](https://mafft.cbrc.jp/alignment/software/)
  - [FastTree](http://www.microbesonline.org/fasttree/)
  - `awk`

---

### arbol.py

- **Descripción**:

  - Lee un archivo Newick (`.nwk`) que contiene etiquetas con accesiones (e.g., `NZ_XXXXXX`), opcionalmente precedidas por un barcode y/o un porcentaje de identidad.
  - Consulta NCBI (Entrez) para obtener el nombre de la especie de cada accesión.
  - Renombra cada hoja del árbol con el formato `barcode_especie` (si aplica) y mantiene el porcentaje de identidad si existe.
  - Genera un archivo Newick renombrado y un CSV (`<original>_especies.csv`) con columnas:
    - **Accesion**: ID de GenBank
    - **Especie**: Nombre científico (sin espacios)
    - **Barcode**: Identificador de muestra (si aplica)

- **Uso**:

  ```bash
  python arbol.py
  ```

  - El script solicitará la ruta al archivo Newick.
  - Salidas:
    - `archivo_renombrado.nwk`: árbol con hojas renombradas
    - `archivo_especies.csv`: resumen de accesiones, especies y barcodes

- **Dependencias**:

  - Python 3.x
  - [Biopython](https://biopython.org/)
    ```bash
    pip install biopython
    ```
  - Configurar tu correo en `Entrez.email` dentro de `arbol.py` para respetar las políticas de NCBI.

---

## Estructura de Salida

Al ejecutar `analisis_seq.sh`, se generará:

```
pipeline_output/
├── blast_db/            Base de datos para BLAST
├── consensus/           Archivos `barcode.fasta` con consensos
├── all_consensus.fasta
├── all_consensus_fixed.fasta
├── aligned_fixed.fasta
└── tree_fixed.nwk       Árbol filogenético final
```

## Contacto

Para dudas o sugerencias, contactar a **Investigacion Desarrollo** <investigacionydesarrollo@ayslab.cl>.
