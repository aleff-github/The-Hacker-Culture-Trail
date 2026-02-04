#!/bin/bash
# Title: Labirinto (librogame)
# Description: Storia interattiva a due scelte con testo scrollabile (UP/DOWN) e scelta LEFT/RIGHT
# Author: ChatGPT
# Version: 1.2
# Category: Games
# Net Mode: NAT
#
# Controlli:
#   UP/DOWN   -> scorri il testo (pagine)
#   LEFT      -> scelta 1 (colonne A_*)
#   RIGHT     -> scelta 2 (colonne B_*)
#   B         -> esci
#
# Note:
# - UI: evita PROMPT per l'interazione continua (causa "doppio click").
# - Mostra testo su console (clear + printf) e legge input con WAIT_FOR_INPUT.
# - Logga su /root/loot/labirinto_librogame_debug.log

set -euo pipefail

PAYLOAD_NAME="labirinto_librogame"
SAVE_KEY="node"
DATA_FILE="./story.tsv"

# Tuning layout (regola se serve)
WRAP_COLS=16
LINES_PER_PAGE=4

LOGFILE="/root/loot/${PAYLOAD_NAME}_debug.log"
mkdir -p /root/loot >/dev/null 2>&1 || true

# Log stdout/stderr su file (utile quando la UI del Pager non mostra l'errore)
exec > >(tee -a "$LOGFILE") 2>&1
if [[ "${DEBUG:-0}" == "1" ]]; then
  set -x
fi

die() { echo "ERRORE: $*" >&2; exit 1; }

# --- Story storage ---
declare -A TEXT A_LABEL A_NEXT B_LABEL B_NEXT
# Pages buffer (array normale)
declare -a PAGES

load_story() {
  [[ -f "$DATA_FILE" ]] || die "File dati non trovato: $DATA_FILE"

  # TSV: ID<TAB>TEXT<TAB>A_LABEL<TAB>A_NEXT<TAB>B_LABEL<TAB>B_NEXT
  # TEXT usa \n per andare a capo (verra' espanso con printf %b).
  while IFS=$'\t' read -r id text a_label a_next b_label b_next; do
    [[ -z "${id:-}" ]] && continue
    [[ "${id:0:1}" == "#" ]] && continue

    TEXT["$id"]="${text:-}"
    A_LABEL["$id"]="${a_label:-}"
    A_NEXT["$id"]="${a_next:-}"
    B_LABEL["$id"]="${b_label:-}"
    B_NEXT["$id"]="${b_next:-}"
  done < "$DATA_FILE"

  [[ "${#TEXT[@]}" -gt 0 ]] || die "Nessuna scena caricata (controlla TAB/CRLF in story.tsv)"
}

render_text() {
  # Espandi \n in newline reali.
  # shellcheck disable=SC2059
  printf "%b" "$1"
}

wrap_text() {
  # Word-wrap in puro bash (per parole). Nessuna dipendenza da fold/awk.
  # Input: testo con \n già espanso da render_text
  # Output: testo wrappato, una riga per riga, max WRAP_COLS (circa)

  local input
  input="$(render_text "$1")"

  # Normalizza CRLF -> LF (se arrivano \r da Windows)
  input="${input//$'\r'/}"

  local line word out cur
  out=""

  # Legge riga per riga, preservando i newline originali
  while IFS= read -r line; do
    # Riga vuota: preserva
    if [[ -z "$line" ]]; then
      out+=$'\n'
      continue
    fi

    cur=""
    # Spezza la riga in parole (spazi e tab come separatori)
    for word in $line; do
      if [[ -z "$cur" ]]; then
        cur="$word"
      else
        # +1 per lo spazio
        if (( ${#cur} + 1 + ${#word} <= WRAP_COLS )); then
          cur+=" $word"
        else
          out+="$cur"$'\n'
          cur="$word"
        fi
      fi
    done

    # Se resta qualcosa nel buffer di riga, flush
    out+="$cur"$'\n'
  done <<< "$input"

  printf "%s" "$out"
}

make_pages() {
  # Crea PAGES[] da un testo già wrappato (una riga per riga).
  local wrapped="$1"
  PAGES=()

  local -a lines
  mapfile -t lines < <(printf "%s\n" "$wrapped")

  local i=0
  while (( i < ${#lines[@]} )); do
    local chunk=""
    for ((k=0; k<LINES_PER_PAGE && i<${#lines[@]}; k++, i++)); do
      chunk+="${lines[$i]}"$'\n'
    done
    PAGES+=("$chunk")
  done

  ((${#PAGES[@]})) || PAGES+=("")
}

# --- UI on console (no PROMPT) ---
clear_console() {
  printf "\033[2J\033[H"
}

draw_screen() {
  local page_text="$1"
  local p="$2"
  local total="$3"
  local a="$4"
  local b="$5"

  clear_console
  printf "Labirinto (librogame)\n"
  printf "Pag %d/%d\n\n" "$((p+1))" "$total"
  printf "%s" "$page_text"
  printf "\n[UP/DOWN] scorri   [<] %s   [>] %s   [B] esci\n" "$a" "$b"
}

present_node_scroll_choice() {
  # UP/DOWN scorrono; LEFT/RIGHT scelgono. Ritorna "A" (LEFT) o "B" (RIGHT).
  local text="$1"
  local a="$2"
  local b="$3"

  local wrapped
  wrapped="$(wrap_text "$text")"
  make_pages "$wrapped"

  local p=0
  local total=${#PAGES[@]}

  while true; do
    draw_screen "${PAGES[$p]}" "$p" "$total" "$a" "$b"

    local btn
    btn="$(WAIT_FOR_INPUT)" || exit 0
    case "$btn" in
      UP)    (( p > 0 )) && ((p--)) ;;
      DOWN)  (( p < total-1 )) && ((p++)) ;;
      LEFT)  echo "A"; return 0 ;;
      RIGHT) echo "B"; return 0 ;;
      B)     exit 0 ;;
    esac
  done
}

# --- Save / restore progress ---
save_node() {
  PAYLOAD_SET_CONFIG "$PAYLOAD_NAME" "$SAVE_KEY" "$node" >/dev/null 2>&1 || true
}

reset_progress() {
  PAYLOAD_CLEAR_CONFIG "$PAYLOAD_NAME" "$SAVE_KEY" >/dev/null 2>&1 || true
  node="CASA"
}

echo "=== ${PAYLOAD_NAME} start $(date -Iseconds) ==="
echo "DATA_FILE=$DATA_FILE"
echo "WRAP_COLS=$WRAP_COLS LINES_PER_PAGE=$LINES_PER_PAGE"

load_story

node="$(PAYLOAD_GET_CONFIG "$PAYLOAD_NAME" "$SAVE_KEY" 2>/dev/null || true)"
[[ -n "${node:-}" ]] || node="CASA"

if [[ -z "${TEXT[$node]+x}" ]]; then
  echo "Nodo salvato inesistente, reset a CASA"
  node="CASA"
fi

while true; do
  local_text="${TEXT[$node]}"
  local_a="${A_LABEL[$node]}"
  local_b="${B_LABEL[$node]}"

  [[ -n "$local_text" ]] || die "Testo mancante per nodo: $node"
  [[ -n "$local_a" && -n "$local_b" ]] || die "Etichette mancanti per nodo: $node"

  choice="$(present_node_scroll_choice "$local_text" "$local_a" "$local_b")"

  if [[ "$choice" == "A" ]]; then
    node="${A_NEXT[$node]}"
  else
    node="${B_NEXT[$node]}"
  fi

  case "$node" in
    "__EXIT__")
      echo "Exit requested"
      clear_console
      printf "Uscita.\n"
      exit 0
      ;;
    "__RESET__")
      echo "Reset requested"
      reset_progress
      save_node
      continue
      ;;
  esac

  if [[ -z "${TEXT[$node]+x}" ]]; then
    echo "Nodo '$node' non trovato. Reset a CASA."
    node="CASA"
  fi

  save_node
done

exit 0
