#!/bin/bash

# pipeline_20250714.sh
# Uso: bash pipeline_20250714.sh /ruta/a/directorio con Bacillus_ref.fasta dentro

set -e

# Configuración general
INPUT_DIR="$1"
OUTPUT_DIR="$INPUT_DIR/pipeline_output"
CONS_DIR="$OUTPUT_DIR/consensus"
ALIGNMENT="$OUTPUT_DIR/aligned_fixed.fasta"
TREE="$OUTPUT_DIR/tree_fixed.nwk"
BLAST_DB="$OUTPUT_DIR/blast_db/bacillus_db"
REF_FASTA="Bacillus_ref.fasta"
THREADS=4

mkdir -p "$OUTPUT_DIR"
mkdir -p "$CONS_DIR"
mkdir -p "$OUTPUT_DIR/blast_db"

# Crear base de datos BLAST si no existe
if [ ! -f "$BLAST_DB.nsq" ]; then
  echo "🧪 Construyendo base de datos BLAST..."
  makeblastdb -in "$INPUT_DIR/$REF_FASTA" -dbtype nucl -out "$BLAST_DB"
fi

# Procesar cada barcode*
for BARCODE_DIR in "$INPUT_DIR"/barcode*/; do
  BARCODE=$(basename "$BARCODE_DIR")
  echo "🧪 Procesando $BARCODE..."

  # Concatenar reads
  cat "$BARCODE_DIR"/*.fastq.gz > "$OUTPUT_DIR/${BARCODE}_merged.fastq.gz"

  # Obtener referencia temporal (lectura más larga)
  zcat "$OUTPUT_DIR/${BARCODE}_merged.fastq.gz" | paste - - - - \
    | awk '{print length($2)"\t"$0}' | sort -nr | cut -f2- | head -n1 | tr "\t" "\n" > "$OUTPUT_DIR/ref_${BARCODE}.fastq"
  seqtk seq -A "$OUTPUT_DIR/ref_${BARCODE}.fastq" > "$OUTPUT_DIR/ref_${BARCODE}.fasta"

  # Indexar referencia temporal
  minimap2 -d "$OUTPUT_DIR/ref_${BARCODE}.mmi" "$OUTPUT_DIR/ref_${BARCODE}.fasta"

  # Alinear reads a referencia
  minimap2 -ax map-ont "$OUTPUT_DIR/ref_${BARCODE}.mmi" "$OUTPUT_DIR/${BARCODE}_merged.fastq.gz" | \
    samtools sort -o "$OUTPUT_DIR/${BARCODE}.bam"
  samtools index "$OUTPUT_DIR/${BARCODE}.bam"

  # Ejecutar Medaka
  medaka_consensus -i "$OUTPUT_DIR/${BARCODE}_merged.fastq.gz" \
                   -d "$OUTPUT_DIR/ref_${BARCODE}.fasta" \
                   -o "$OUTPUT_DIR/medaka_${BARCODE}" -t "$THREADS"

  # Copiar consenso a carpeta general
  seqkit replace -p "^.*$" -r "$BARCODE" "$OUTPUT_DIR/medaka_${BARCODE}/consensus.fasta" \
  -o "$CONS_DIR/${BARCODE}.fasta"

done

# Concatenar todos los consensos
cat "$CONS_DIR"/*.fasta > "$OUTPUT_DIR/all_consensus.fasta"

# Identificar con BLAST
blastn -query "$OUTPUT_DIR/all_consensus.fasta" -db "$BLAST_DB" \
       -outfmt "6 qseqid sseqid pident length evalue bitscore" \
       -max_target_seqs 1 -perc_identity 80 > "$OUTPUT_DIR/blast_results.tsv"

# Crear archivo de reemplazos
awk -F"\t" '
{
  barcode=$1
  gsub(/[^A-Za-z0-9_.-]/, "_", $2)  # limpia especie
  species=$2
  identity=sprintf("%.2f", $3)
  print barcode "\t" barcode"__"species"__"identity"%"
}' "$OUTPUT_DIR/blast_results.tsv" > "$OUTPUT_DIR/replacements.tsv"

# Renombrar secuencias en all_consensus.fasta
seqkit replace -p "^(\S+)" -k "$OUTPUT_DIR/replacements.tsv" -r "{kv}" "$OUTPUT_DIR/all_consensus.fasta" \
  -o "$OUTPUT_DIR/all_consensus_fixed.fasta"

echo "✅ Pipeline completo. Resultados en: $OUTPUT_DIR"
