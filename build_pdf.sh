#!/bin/bash
set -euo pipefail

# --- Default flags ---
DO_BUILD=false
DO_CLEAN_AFTER=false
DO_ONLY_CLEAN=false
TEX_FILE=""

# --- Usage ---
usage() {
  echo "Usage:"
  echo "  $0 --build <file.tex>           Compile LaTeX file (no cleanup)"
  echo "  $0 --build <file.tex> --clean   Compile and cleanup after build"
  echo "  $0 --only-clean <file.tex>      Cleanup temporary LaTeX files for this file only"
  echo "  $0 --help                       Show this help"
  exit 1
}

# --- Cleanup function ---
cleanup() {
  local RAW_PARAM="$1"
  
  local DIR_NAME
  DIR_NAME=$(dirname "$RAW_PARAM")

  local OLD_PWD="$PWD"
  echo "Cleaning auxiliary LaTeX files recursively in: ${DIR_NAME} ..."
  
  # Si sposta nella cartella del progetto
  cd "$DIR_NAME"

  # Lista di tutti i pattern di file ausiliari da cercare e distruggere
  local PATTERNS=(
    "*.aux" "*.bbl" "*.blg" "*.brf" "*.log" "*.nav" "*.out" "*.snm" 
    "*.toc" "*.lof" "*.lot" "*.fls" "*.fdb_latexmk" "*.synctex.gz" 
    "*.synctex(busy)" "*.pdfsync" "*.xdv" "*.dvi" "*.acn" "*.acr" 
    "*.alg" "*.glg" "*.glo" "*.gls" "*.ist" "*-blx.bib" "*-blx.bib.pdf" 
    "*.bcf" "*.run.xml" "*~" "*.bak" "*.tmp" "*.swp"
  )

  # Esegue una ricerca ricorsiva per ogni pattern eliminando i file trovati
  for pattern in "${PATTERNS[@]}"; do
    find . -type f -name "$pattern" -delete
  done

  # Ritorna alla cartella originaria
  cd "$OLD_PWD"
  echo "Cleanup completed."
}

# --- Build function ---
build() {
  local RAW_PARAM="$1"

  if [[ ! -f "$RAW_PARAM" ]]; then
    echo "Error: File '$RAW_PARAM' does not exist."
    exit 2
  fi

  if [[ ! -r "$RAW_PARAM" ]]; then
    echo "Error: File '$RAW_PARAM' is not readable."
    exit 3
  fi

  if [[ "$RAW_PARAM" != *.tex ]]; then
    echo "Error: File must have a .tex extension."
    exit 4
  fi

  local DIR_NAME
  DIR_NAME=$(dirname "$RAW_PARAM")
  local BASE_NAME
  BASE_NAME=$(basename "$RAW_PARAM")
  local NO_EXT="${BASE_NAME%.tex}"

  local OLD_PWD="$PWD"

  echo "Starting compilation for: $BASE_NAME (in directory: $DIR_NAME)"
  cd "$DIR_NAME"

  # --- PASS 1 ---
  echo "   [1/3] Running pdflatex..."
  pdflatex -interaction=nonstopmode "$BASE_NAME" > /dev/null 2>&1 || {
    echo "Error: pdflatex failed at Pass 1. Check ${NO_EXT}.log for details."
    cd "$OLD_PWD"
    exit 5
  }

  # --- BIBLIOGRAPHY DETECTION & EXECUTION ---
  if [[ -f "${NO_EXT}.bcf" ]] && grep -q 'backend="biber"' "${NO_EXT}.bcf" 2>/dev/null; then
    echo "   [XML] BibLaTeX (Biber) detected. Processing bibliography..."
    biber "$NO_EXT" > /dev/null 2>&1 || echo "   Warning: biber reported some issues."
    
  elif grep -qE "(\\citation|\\bibdata)" "${NO_EXT}.aux" 2>/dev/null; then
    echo "   [AUX] BibTeX detected. Processing bibliography..."
    bibtex "$NO_EXT" > /dev/null 2>&1 || echo "   Warning: bibtex reported some issues."
    
  else
    echo "   [-] No bibliography needed."
  fi
  
  # --- PASS 2 ---
  echo "   [2/3] Running pdflatex (cross-references)..."
  pdflatex -interaction=nonstopmode "$BASE_NAME" > /dev/null 2>&1 || {
    echo "Error: pdflatex failed at Pass 2. Check ${NO_EXT}.log."
    cd "$OLD_PWD"
    exit 6
  }

  # --- PASS 3 ---
  echo "   [3/3] Running pdflatex (final assembly)..."
  pdflatex -interaction=nonstopmode "$BASE_NAME" > /dev/null 2>&1 || {
    echo "Error: pdflatex failed at Pass 3. Check ${NO_EXT}.log."
    cd "$OLD_PWD"
    exit 7
  }

  echo "PDF build successfully completed: ${NO_EXT}.pdf"
  cd "$OLD_PWD"
}

# --- Option parsing ---
PARSED=$(getopt --options "" --long build:,clean,only-clean:,help --name "$0" -- "$@") || usage
eval set -- "$PARSED"

while true; do
  case "$1" in
    --build)
      TEX_FILE="$2"
      DO_BUILD=true
      shift 2
      ;;
    --clean)
      DO_CLEAN_AFTER=true
      shift
      ;;
    --only-clean)
      TEX_FILE="$2"
      DO_ONLY_CLEAN=true
      shift 2
      ;;
    --help)
      usage
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# --- Execute logic ---
if [[ "$DO_ONLY_CLEAN" == true ]]; then
  if [[ -z "$TEX_FILE" ]]; then
    echo "Error: --only-clean requires a .tex file."
    usage
  fi
  cleanup "$TEX_FILE"
  exit 0
fi

if [[ "$DO_BUILD" == true ]]; then
  build "$TEX_FILE"
  if [[ "$DO_CLEAN_AFTER" == true ]]; then
    cleanup "$TEX_FILE"
  fi
  exit 0
fi

usage
