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
  echo "  $0 --only-clean                 Cleanup temporary LaTeX files only"
  echo "  $0 --help                       Show this help"
  exit 1
}

# --- Cleanup function ---
cleanup() {
  echo "Cleaning auxiliary LaTeX files..."
  find . -type f \( \
    -name "*.aux" -o \
    -name "*.bbl" -o \
    -name "*.blg" -o \
    -name "*.brf" -o \
    -name "*.log" -o \
    -name "*.nav" -o \
    -name "*.out" -o \
    -name "*.snm" -o \
    -name "*.toc" -o \
    -name "*.lof" -o \
    -name "*.lot" -o \
    -name "*.fls" -o \
    -name "*.fdb_latexmk" -o \
    -name "*.synctex.gz" -o \
    -name "*.synctex(busy)" -o \
    -name "*.pdfsync" -o \
    -name "*.xdv" -o \
    -name "*.dvi" -o \
    -name "*~" -o \
    -name "*.bak" -o \
    -name "*.tmp" -o \
    -name "*.swp" -o \
    -name "*.gz" -o \
    -name "*.acn" -o \
    -name "*.acr" -o \
    -name "*.alg" -o \
    -name "*.glg" -o \
    -name "*.glo" -o \
    -name "*.gls" -o \
    -name "*.ist" -o \
    -name "*.blx.bib" -o \
    -name "*.blx.bib.pdf" \
  \) -exec rm -v "{}" \;
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

  local NO_EXT="${RAW_PARAM%.tex}"

  echo "Compiling: $RAW_PARAM"

  pdflatex "$RAW_PARAM" && \
  bibtex "$NO_EXT" && \
  pdflatex "$RAW_PARAM" && \
  pdflatex "$RAW_PARAM"

  echo "PDF build completed: ${NO_EXT}.pdf"
}

# --- Option parsing ---
PARSED=$(getopt --options "" --long build:,clean,only-clean,help --name "$0" -- "$@") || usage
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
      DO_ONLY_CLEAN=true
      shift
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
  cleanup
  exit 0
fi

if [[ "$DO_BUILD" == true ]]; then
  build "$TEX_FILE"
  if [[ "$DO_CLEAN_AFTER" == true ]]; then
    cleanup
  fi
  exit 0
fi

# If nothing was done
usage
