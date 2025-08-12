#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Pipeline: MAFFT -> (trimAl opcional) -> IQ-TREE 2
# - Concatena: referencia + input (no altera los originales)
# - Alinea con MAFFT (opción para corregir orientación)
# - (Opcional) recorta con trimAl
# - Infiera árbol con IQ-TREE 2 (ModelFinder, UFBoot, aLRT)
#
# Requisitos: mafft, iqtree2 (o iqtree)
#  * trimal sólo si eliges recortar
# ------------------------------------------------------------

usage() {
  cat <<'EOF'
Uso:
  pipeline_arbol.sh -i INPUT.fasta -r REFERENCIA.fasta [-o outdir] [-p prefijo]
                    [-t hilos] [-m modelo] [-B boot] [-A alrt] [-S seed]
                    [--fix-orientation yes|no] [--trimal-opts "opciones"]

Parámetros:
  -i  FASTA con 1+ secuencias a agregar (obligatorio)
  -r  FASTA de referencia (obligatorio)  [NO se modifica]
  -o  Directorio de salida (def: results_YYYYmmdd_HHMMSS)
  -p  Prefijo para archivos de salida (def: phylo)
  -t  Hilos/threads para MAFFT e IQ-TREE (def: AUTO)
  -m  Modelo en IQ-TREE (def: MFP)
  -B  Réplicas UFBoot (def: 1000)
  -A  Réplicas SH-aLRT (def: 1000)
  -S  Semilla aleatoria IQ-TREE (def: 42)
  --fix-orientation  yes|no (def: yes) -> usa MAFFT --adjustdirectionaccurately
  --trimal-opts  Opciones para trimAl (def: -automated1)

Ejemplo:
  pipeline_arbol.sh -i nuevas.fasta -r ref.fasta -o out -p mi_arbol -t 8 \
    --fix-orientation yes
EOF
}

# ------------------ Parseo de argumentos --------------------
INPUT=""
REF=""
OUTDIR="results_$(date +%Y%m%d_%H%M%S)"
PREFIX="phylo"
THREADS="AUTO"
MODEL="MFP"
BOOT=1000
ALRT=1000
SEED=42
TRIMAL_OPTS="-automated1"
FIX_ORI="yes"   # yes|no

TEMP_ARGS=()
while (( "$#" )); do
  case "$1" in
    --trimal-opts) TRIMAL_OPTS="${2:-}"; shift 2 ;;
    --fix-orientation) FIX_ORI="${2:-yes}"; shift 2 ;;
    -i) INPUT="$2"; shift 2 ;;
    -r) REF="$2"; shift 2 ;;
    -o) OUTDIR="$2"; shift 2 ;;
    -p) PREFIX="$2"; shift 2 ;;
    -t) THREADS="$2"; shift 2 ;;
    -m) MODEL="$2"; shift 2 ;;
    -B) BOOT="$2"; shift 2 ;;
    -A) ALRT="$2"; shift 2 ;;
    -S) SEED="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "Error: Opción no reconocida: $1" >&2
      usage; exit 1 ;;
    *)
      TEMP_ARGS+=("$1"); shift ;;
  esac
done
set -- "${TEMP_ARGS[@]:-}"

# ------------------ Validaciones ----------------------------
[[ -z "$INPUT" || -z "$REF" ]] && { echo "Falta -i y/o -r"; usage; exit 1; }
[[ ! -s "$INPUT" ]] && { echo "INPUT vacío o inexistente: $INPUT" >&2; exit 1; }
[[ ! -s "$REF" ]] && { echo "REF vacío o inexistente: $REF" >&2; exit 1; }

command -v mafft >/dev/null 2>&1 || { echo "Falta 'mafft' en PATH" >&2; exit 1; }

if command -v iqtree2 >/dev/null 2>&1; then
  IQTREE_BIN="iqtree2"
elif command -v iqtree >/dev/null 2>&1; then
  IQTREE_BIN="iqtree"
else
  echo "Falta 'iqtree2' o 'iqtree' en PATH" >&2; exit 1
fi

mkdir -p "$OUTDIR"

COMBINED="$OUTDIR/${PREFIX}.combined.fasta"
ALN="$OUTDIR/${PREFIX}.aln.fasta"
TRIM="$OUTDIR/${PREFIX}.trimmed.fasta"
IQTPRE="$OUTDIR/${PREFIX}"

# ------------------ Concatenación ---------------------------
cat "$REF" "$INPUT" > "$COMBINED"

# ------------------ Alineamiento (MAFFT) --------------------
if [[ "$THREADS" == "AUTO" ]]; then
  MAFFT_THR="-1"
else
  MAFFT_THR="$THREADS"
fi

MAFFT_FLAGS=(--thread "$MAFFT_THR" --auto)
if [[ "$FIX_ORI" == "yes" ]]; then
  MAFFT_FLAGS+=(--adjustdirectionaccurately)
  echo "MAFFT: corrigiendo orientación (--adjustdirectionaccurately)."
else
  echo "MAFFT: SIN corrección de orientación."
fi

mafft "${MAFFT_FLAGS[@]}" "$COMBINED" > "$ALN"

# ------------------ Prompt: ¿Recortar con trimAl? -----------
echo
read -r -p "¿Deseas recortar el alineamiento con trimAl? [s/N]: " RESP
RESP="${RESP:-N}"
RESP_LC="$(printf "%s" "$RESP" | tr '[:upper:]' '[:lower:]')"

USE_TRIMAL=false
if [[ "$RESP_LC" == "s" || "$RESP_LC" == "si" || "$RESP_LC" == "sí" || "$RESP_LC" == "y" || "$RESP_LC" == "yes" ]]; then
  USE_TRIMAL=true
fi

TREE_INPUT="$ALN"

if $USE_TRIMAL; then
  if ! command -v trimal >/dev/null 2>&1; then
    echo "Elegiste recortar pero 'trimal' no está en PATH." >&2
    echo "Instálalo (p.ej., mamba install -c bioconda trimal) o responde 'N'." >&2
    exit 1
  fi
  echo "Recortando con: trimal $TRIMAL_OPTS -in \"$ALN\" -out \"$TRIM\" -fasta"
  trimal $TRIMAL_OPTS -in "$ALN" -out "$TRIM" -fasta
  TREE_INPUT="$TRIM"
else
  echo "Saltando recorte con trimAl. Se usará el alineamiento completo para el árbol."
fi

# ------------------ Árbol (IQ-TREE 2) ----------------------
if [[ "$THREADS" == "AUTO" ]]; then
  NT_ARG="AUTO"
else
  NT_ARG="$THREADS"
fi

"$IQTREE_BIN" \
  -s "$TREE_INPUT" \
  -m "$MODEL" \
  -B "$BOOT" \
  -alrt "$ALRT" \
  -seed "$SEED" \
  -st DNA \
  -nt "$NT_ARG" \
  -pre "$IQTPRE"

# ------------------ Resumen --------------------------------
echo "----------------------------------------------------------"
echo "Listo. Archivos clave:"
echo "  Combined FASTA:    $COMBINED"
echo "  MAFFT alignment:   $ALN"
if $USE_TRIMAL; then
  echo "  trimAl alignment:  $TRIM"
  echo "  Árbol basado en:   $TRIM"
else
  echo "  *No se aplicó trimAl*"
  echo "  Árbol basado en:   $ALN"
fi
echo "  Árbol (Newick):    ${IQTPRE}.treefile"
echo "  Reporte IQ-TREE:   ${IQTPRE}.iqtree"
echo "  Log IQ-TREE:       ${IQTPRE}.log"
echo "----------------------------------------------------------"
echo "Notas:"
echo " - Si se usó --adjustdirectionaccurately, MAFFT puede marcar headers invertidos con '_R_'."
echo " - Verifica que los IDs (>id) sean únicos entre referencia e input."
