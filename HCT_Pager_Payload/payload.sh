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
node_id="WELCOME"
NEXT1=""
NEXT2=""

LANG_CODE="en"
LOCALE_FILE="${LOCALES_DIR}/${LANG_CODE}.lang"

_lang_get() {
  local key="$1"
  local file="$2"

  awk -F'=' -v k="$key" '$1==k{ $1=""; sub(/^=/,""); print; exit }' "$file"
}

sanitize_ids() {
  _trim_var() {
    local __name="$1"
    local __v="${!__name}"

    # rimuovi \r ovunque
    __v="${__v//$'\r'/}"

    # trim sinistra (spazi+tab)
    __v="${__v#"${__v%%[!$' \t']*}"}"
    # trim destra (spazi+tab)
    __v="${__v%"${__v##*[!$' \t']}"}"

    printf -v "$__name" '%s' "$__v"
  }

  _trim_var "node_id"
  _trim_var "NEXT1"
  _trim_var "NEXT2"
}

rand_0_49() {
  echo $(( RANDOM % 50 ))
}

resolve_next() {
  local raw="$1"

  # pulizia base (CR + trim spazi/tab)
  raw="${raw//$'\r'/}"
  raw="${raw#"${raw%%[!$' \t']*}"}"
  raw="${raw%"${raw##*[!$' \t']}"}"

  # Caso normale: non è RANDOM
  if [[ "$raw" != RANDOM:* ]]; then
    node_id="$raw"
    return 0
  fi

  # Caso RANDOM: X@w1|Y@w2 (continuiamo a leggere così, ma i pesi li ignoriamo)
  local spec="${raw#RANDOM:}"
  local left="${spec%%|*}"
  local right="${spec#*|}"

  local n1="${left%@*}"   # es: FROGGER.WIN
  local n2="${right%@*}"  # es: FROGGER.LOSE

  local r
  r="$(rand_0_49)"
  LOG "Valore random. $r"

  if [ "$r" -eq 42 ]; then
    node_id="$n1"
  else
    node_id="$n2"
  fi

  return 0
}

t() {
  local key="$1"
  local val=""

  if [ -f "$LOCALE_FILE" ]; then
    val="$(_lang_get "$key" "$LOCALE_FILE" || true)"
  fi

  printf '%b' "$val"
}

node_nexts() {
  local id="$1"
  local _id n1 n2 extra

  # reset globali
  NEXT1=""
  NEXT2=""

  # Legge riga per riga: ID<TAB>NEXT1<TAB>NEXT2
  while IFS=$'\t' read -r _id n1 n2 extra; do
    # rimuovi BOM solo sul primo campo (se presente)
    _id="${_id#$'\ufeff'}"

    # rimuovi CR (file Windows) da tutti i campi importanti
    _id="${_id//$'\r'/}"
    n1="${n1//$'\r'/}"
    n2="${n2//$'\r'/}"

    if [ "$_id" = "$id" ]; then
      NEXT1="$n1"
      NEXT2="$n2"
      LOG "DEBUG node_nexts: id=[$id] NEXT1=[$NEXT1] NEXT2=[$NEXT2]"
      return 0
    fi
  done < "$STORY_TSV"

  LOG "DEBUG node_nexts: id=[$id] NON TROVATO"
  return 2
}

choose_next_node_popup() {
  local node_id="$1"
  local c1 c2
  local key

  c1="$(t "p.${node_id}.c1")"
  c2="$(t "p.${node_id}.c2")"
  [ -z "$c1" ] && c1="Scelta 1"
  [ -z "$c2" ] && c2="Scelta 2"

  # Mostra le due opzioni
  PROMPT "[←] ${c1}\n[→] ${c2}\n\n"

  # Aspetta LEFT/RIGHT
  while true; do
    key="$(WAIT_FOR_INPUT)"
    case "$key" in
      B) exit 0 ;;
      LEFT)  return 1 ;;  # scelta c1
      RIGHT) return 2 ;;  # scelta c2
      *)     ;;           # ignora altri tasti
    esac
  done
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

on_enter_node() {
  # Chiamata ogni volta che si entra in un nodo (prima di mostrare il testo)
  local id="$1"

  case "$id" in
    SCOPRI-DEFCON)
      RINGTONE "LoveMeBetter:d=16,o=4,b=136:16.a#4,16.p,16.a#4,8p,8.a#4,16.p,16.a#4,32.a4,32f4,16.p,32.a#4,32g4,32.p,32a4,4a#4,8p,8.a#4,16.p,8.a#4,16.p,8a#4,32.g#4,32f#4,32f4,4p,8.a#4,16.p,32.a#4,32.p,16.a#4,16.p,16.a#4,8p,8.a#4,16.p,16.a#4,32.a4,32f4,16.p,32.a#4,32g4,32.p,32a4,4a#4,8p,8.a#4,16.p,8.a#4,16.p,8a#4,32.g#4,32f#4,32f4,4p,8.a#4,16.p,32.a#4,32.p,16.a#4,16.p,16.a#4,8p,8.a#4,16.p,16.a#4,32.a4,32f4,16.p,32.a#4,32g4,32.p,32a4,4a#4,8p,8.a#4,16.p,8.a#4,16.p,8a#4,32.g#4,32f#4,32f4,4p,8.a#4,16.p,32.a#4,32.p,16.a#4,16.p,16.a#4,8p,8.a#4,16.p,16.a#4,32.a4,32f4,16.p,32.a#4,32g4,32.p,32a4,4a#4,8p,8.a#4,16.p,8.a#4,16.p,8a#4,32.g#4,32f#4,32f4,4p,8.a#4,16.p,32.a#4,32.p,16.a#4,16.p,16.a#4,8p,8.a#4,16.p,16.a#4,32.a4,32f4,16.p,32.a#4,32g4,32.p,32a4,4a#4,8p,8.a#4,16.p,8.a#4,16.p,8a#4,32.g#4,32f#4,32f4,4p,8.a#4,16.p,32.a#4,32.p,16.a#4"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# UI demo: popup "Hello World" -> popup (Ricomincia / Termina)
# -----------------------------------------------------------------------------

# Recupero label pulsanti dal file lingua, con fallback hardcoded.
# BTN_NEXT="$(t ui.btn.next)"
# [ -z "$BTN_NEXT" ] && BTN_NEXT="Vai avanti"

# BTN_RESTART="$(t ui.btn.restart)"
# [ -z "$BTN_RESTART" ] && BTN_RESTART="Ricomincia"

# BTN_QUIT="$(t ui.btn.quit)"
# [ -z "$BTN_QUIT" ] && BTN_QUIT="Termina"

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
  local CHUNK_SIZE=250

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
    PROMPT "${chunk}\n\n[←]   [→]"

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
    esac
  done
}

check_lang() {

  # Ora lang è garantito essere it o en
  if [[ "$LANG_CODE" == "it" ]]; then
    question="Would you like to continue in Italian?"
    other_lang="en"
  else
    question="Would you like to continue in English?"
    other_lang="it"
  fi

  resp=$(CONFIRMATION_DIALOG "$question") || exit 0

  if [[ "$resp" == "0" ]]; then
    LANG_CODE="${other_lang}"
    LOCALE_FILE="${LOCALES_DIR}/${LANG_CODE}.lang"
  fi
}

main() {
  
  check_lang

  while true; do
    show_node_popup "$node_id"

    node_nexts "$node_id" || exit 0
    sanitize_ids
    on_enter_node "$node_id"
    
    set +e
    choose_next_node_popup "$node_id"
    choice=$?
    set -e
    case "$choice" in
      1)
          resolve_next "$NEXT1"
          sanitize_ids
          if [[ "$node_id" == *END* ]]; then
            exit 0
          fi
          ;;
      2)
          resolve_next "$NEXT2"
          sanitize_ids
          if [[ "$node_id" == *END* ]]; then
            exit 0
          fi
          ;;
      *)
          exit 0
          ;;
    esac

    # Se per qualche motivo il TSV punta a vuoto, esci
    [ -z "$node_id" ] && exit 0
  done
}

# Avvio
main