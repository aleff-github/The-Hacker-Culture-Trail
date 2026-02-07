#!/bin/bash
# -----------------------------------------------------------------------------
# The Hacker Culture Trail - BASE SKELETON (Pager)
# Obiettivo di questo file:
# - verificare e preparare caricamento di story/story.tsv (TSV) e locales/it.lang
# - mostrare un popup "Hello World" con un unico step "Vai avanti"
# - poi mostrare un popup con due scelte: "Ricomincia" e "Termina"
#
# Nota: questo è un "programma base" su cui costruire il gioco. Non usa la storia.
# -----------------------------------------------------------------------------

set -euo pipefail

# Nome payload (usato eventualmente per config persistente; qui non è indispensabile)
PAYLOAD_NAME="hctrail"

# Directory base del payload (cartella dove sta questo payload.sh)
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Percorsi standard richiesti dal tuo progetto
STORY_TSV="${BASE_DIR}/story/story.tsv"
LOCALES_DIR="${BASE_DIR}/locales"

# In questo esempio fissiamo la lingua a "it"
LANG_CODE="it"
LOCALE_FILE="${LOCALES_DIR}/${LANG_CODE}.lang"

# -----------------------------------------------------------------------------
# i18n minimale (key=value in locales/<lang>.lang)
# - È lo stesso approccio che già usi nello script attuale. :contentReference[oaicite:1]{index=1}
# - Qui lo manteniamo perché ti serve come base “pulita”.
# -----------------------------------------------------------------------------

# Legge il valore associato a una chiave "key" da un file .lang.
# Formato atteso:
#   ui.btn.next=Vai avanti
#   ui.btn.restart=Ricomincia
#   ui.btn.quit=Termina
_lang_get() {
  local key="$1"
  local file="$2"

  # Match esatto della chiave prima del primo '='
  # Se trova la riga, stampa tutto ciò che è dopo '=' e termina.
  awk -F'=' -v k="$key" '$1==k{ $1=""; sub(/^=/,""); print; exit }' "$file"
}

# Funzione "t" (translate): restituisce la stringa per una chiave.
# Se la chiave non esiste o il file manca, restituisce stringa vuota.
t() {
  local key="$1"
  local val=""

  if [ -f "$LOCALE_FILE" ]; then
    val="$(_lang_get "$key" "$LOCALE_FILE" || true)"
  fi

  # Interpreta \n e sequenze escaped (come nel tuo script) :contentReference[oaicite:2]{index=2}
  printf '%b' "$val"
}

# -----------------------------------------------------------------------------
# TSV: funzioni base per “caricare” la storia (qui NON la useremo)
# - Ti servono come fondamenta: leggere una riga per id e prendere i next node.
# -----------------------------------------------------------------------------

# Restituisce la riga TSV corrispondente a un id nodo (prima colonna).
# TSV atteso:
#   <id>\t<next1>\t<next2>\t...
node_line() {
  local id="$1"
  awk -F'\t' -v k="$id" '$1==k{print; exit}' "$STORY_TSV"
}

# Restituisce il “prossimo nodo” (colonna 2 o 3) dato un id e una scelta (1/2).
# Qui è solo dimostrativo: non lo useremo nella demo Hello World.
get_next() {
  local node_id="$1"
  local choice="$2"

  local line=""
  line="$(node_line "$node_id" || true)"
  [ -n "$line" ] || { echo ""; return; }

  if [ "$choice" = "1" ]; then
    echo "$line" | cut -f2
  else
    echo "$line" | cut -f3
  fi
}

# -----------------------------------------------------------------------------
# Controlli di sanità: esistenza file base
# -----------------------------------------------------------------------------

# Se manca lo story.tsv, blocchiamo tutto: la base progetto deve esserci.
if [ ! -f "$STORY_TSV" ]; then
  ERROR_DIALOG "Missing story.tsv in: ${STORY_TSV}"
  exit 1
fi

# Se manca il file lingua italiano, blocchiamo (perché tu lo vuoi caricato).
if [ ! -f "$LOCALE_FILE" ]; then
  ERROR_DIALOG "Missing locale file in: ${LOCALE_FILE}"
  exit 1
fi

# -----------------------------------------------------------------------------
# UI demo: popup "Hello World" -> popup (Ricomincia / Termina)
# -----------------------------------------------------------------------------

# Recupero label pulsanti dal file lingua, con fallback hardcoded.
BTN_NEXT="$(t ui.btn.next)"
[ -z "$BTN_NEXT" ] && BTN_NEXT="Vai avanti"

BTN_RESTART="$(t ui.btn.restart)"
[ -z "$BTN_RESTART" ] && BTN_RESTART="Ricomincia"

BTN_QUIT="$(t ui.btn.quit)"
[ -z "$BTN_QUIT" ] && BTN_QUIT="Termina"

# Funzione che mostra il primo popup.
# Sul Pager, PROMPT è un dialog “one-shot” (un solo bottone di conferma).
# Non sempre permette di cambiare l’etichetta del bottone, quindi mettiamo
# l’istruzione nel testo: è semanticamente “Vai avanti”.

# Mostra un popup per un dato nodo (testo preso dal file lingua).
# Convenzione: nel locales/it.lang il testo sta in node.<ID>.text
# massimo 500 chars
show_node_popup() {
  local node_id="$1"
  local txt chunk
  local CHUNK_SIZE=400

  # txt="$(t "p.${node_id}")"
  # [ -z "$txt" ] && txt="(testo mancante: p.${node_id})"
  txt="$(t "p.${node_id}.body")"
  [ -z "$txt" ] && txt="(testo mancante: p.${node_id}.body)"

  local total_len=${#txt}
  local offset=0

  while true; do
    chunk="${txt:offset:CHUNK_SIZE}"

    # 1) Qui NON usi PROMPT se non supporta frecce.
    # Devi usare la tua routine di disegno (o un dialog che non “mangi” i tasti).
    # ESEMPIO: PROMPT solo come render, ma non va bene se non puoi leggere LEFT.
    # Idealmente: una funzione tipo DRAW_TEXT/SCREEN + hint in basso.
    PROMPT "${chunk}\n\n[← indietro]   [→ avanti]"

    # 2) Aspetta un input “vero”
    key="$(WAIT_FOR_INPUT)"   # <-- deve restituire qualcosa tipo LEFT/RIGHT/OK

    case "$key" in
      LEFT)
        # Vai indietro solo se non sei già a inizio testo
        if [ "$offset" -ge "$CHUNK_SIZE" ]; then
          offset=$((offset - CHUNK_SIZE))
        else
          offset=0
        fi
        ;;
      RIGHT|OK)
        # Se stai mostrando l'ultima pagina, esci (e poi mostri le scelte)
        if [ $((offset + CHUNK_SIZE)) -ge "$total_len" ]; then
          break
        fi
        offset=$((offset + CHUNK_SIZE))
        ;;
      *)
        # Ignora o gestisci altri tasti
        ;;
    esac
  done
}

# Funzione che mostra il secondo popup con due scelte:
# - conferma => Ricomincia
# - annulla  => Termina
#
# Uso CONFIRMATION_DIALOG perché è presente nel tuo script. :contentReference[oaicite:3]{index=3}
# Anche se i bottoni fossero “Yes/No”, nel testo diciamo chiaramente cosa fanno.
show_popup_end() {
  local r=""
  r="$(CONFIRMATION_DIALOG "Cosa vuoi fare?\n\nConferma = $BTN_RESTART\nAnnulla = $BTN_QUIT")" || true
  echo "$r"
}

# Loop principale della demo:
# 1) Hello World
# 2) popup finale: se restart -> ricomincia da capo; se quit -> esce.
main() {
  node_id="WELCOME"

  while true; do
    show_node_popup "${node_id}"

    local res=""
    res="$(show_popup_end)"

    # DUCKYSCRIPT_USER_CONFIRMED è la costante che usi già per conferma. :contentReference[oaicite:4]{index=4}
    if [ "${res:-}" = "${DUCKYSCRIPT_USER_CONFIRMED:-}" ]; then
      # Ricomincia: torna al primo popup
      continue
    else
      # Termina: chiude il payload
      exit 0
    fi
  done
}

# Avvio
main