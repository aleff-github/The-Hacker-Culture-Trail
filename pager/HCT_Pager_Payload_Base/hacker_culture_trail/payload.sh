#!/bin/bash
# Title: The Hacker Culture Trail (game)
# Description: Interactive fiction about hacker culture. Offline. No wireless actions.
# Author: Aleff

set -euo pipefail

PAYLOAD_NAME="hctrail"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORY_TSV="${BASE_DIR}/story/story.tsv"
LOCALES_DIR="${BASE_DIR}/locales"

# --- i18n (key=value .lang files) --------------------------------------------

_lang_get() {
  local key="$1" file="$2"
  # exact-key match before first '='
  awk -F'=' -v k="$key" '$1==k{ $1=""; sub(/^=/,""); print; exit }' "$file"
}

t() {
  local key="$1"
  local val=""
  val="$(_lang_get "$key" "$LOCALE_FILE" || true)"
  if [ -z "$val" ] && [ "$LANG_CODE" != "it" ] && [ -f "${LOCALES_DIR}/it.lang" ]; then
    val="$(_lang_get "$key" "${LOCALES_DIR}/it.lang" || true)"
  fi
  # interpret \n and \\ sequences
  printf '%b' "$val"
}

# --- story graph -------------------------------------------------------------

node_line() {
  local id="$1"
  awk -F'\t' -v k="$id" '$1==k{print; exit}' "$STORY_TSV"
}

get_next() {
  # $1 = node_id, $2 = 1 or 2
  local line
  line="$(node_line "$1")"
  [ -n "$line" ] || { echo ""; return; }
  if [ "$2" = "1" ]; then
    echo "$line" | cut -f2
  else
    echo "$line" | cut -f3
  fi
}

rand_u32() {
  if [ -r /dev/urandom ]; then
    od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' ' | tr -d '\n'
    return
  fi

  local a b c
  a=$RANDOM
  b=$RANDOM
  c=$RANDOM
  echo $(( ((a & 0x7fff) << 17) | ((b & 0x7fff) << 2) | (c & 0x3) ))
}

rand_range() {
  local n="$1"
  [ -z "$n" ] && return 1
  [ "$n" -le 0 ] 2>/dev/null && return 1

  local v limit
  limit=$(( (4294967296 / n) * n ))

  while true; do
    v="$(rand_u32)"
    [ -z "$v" ] && v=0
    if [ "$v" -lt "$limit" ]; then
      echo $(( v % n ))
      return 0
    fi
  done
}

resolve_target() {
  local tgt="${1:-}"
  [[ -z "$tgt" ]] && { echo ""; return; }

    if [[ "$tgt" == RANDOM:* ]]; then
    local list="${tgt#RANDOM:}"
    local -a raw
    IFS='|' read -r -a raw <<< "$list"

    local total=0
    local -a opts
    local -a wts

    local item opt wt
    for item in "${raw[@]}"; do
  
      if [[ "$item" == *"@"* ]]; then
        opt="${item%@*}"
        wt="${item##*@}"
      else
        opt="$item"
        wt="1"
      fi

      if ! [[ "$wt" =~ ^[0-9]+$ ]] || [[ "$wt" -le 0 ]]; then
        wt="1"
      fi

      opts+=("$opt")
      wts+=("$wt")
      total=$(( total + wt ))
    done

    [[ "$total" -le 0 ]] && { echo ""; return; }

    local r=""
    if [[ -n "${RANDOM-}" ]]; then
      r="$RANDOM"
    else
      r="$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' ')" || r="0"
      [[ -z "$r" ]] && r="0"
    fi
    r=$(( r % total ))

    # pick based on cumulative weights
    local acc=0
    local i=0
    for i in "${!opts[@]}"; do
      acc=$(( acc + wts[i] ))
      if [[ "$r" -lt "$acc" ]]; then
        echo "${opts[i]}"
        return
      fi
    done

    echo "${opts[0]}"
    return
  fi

  echo "$tgt"
}

# --- state -------------------------------------------------------------------

LANG_CODE="$(PAYLOAD_GET_CONFIG "$PAYLOAD_NAME" lang 2>/dev/null || true)"
[ -z "${LANG_CODE:-}" ] && LANG_CODE="it"

LOCALE_FILE="${LOCALES_DIR}/${LANG_CODE}.lang"
if [ ! -f "$LOCALE_FILE" ]; then
  LANG_CODE="it"
  LOCALE_FILE="${LOCALES_DIR}/it.lang"
fi

NODE="$(PAYLOAD_GET_CONFIG "$PAYLOAD_NAME" node 2>/dev/null || true)"
[ -z "${NODE:-}" ] && NODE="0"

HISTORY="$(PAYLOAD_GET_CONFIG "$PAYLOAD_NAME" hist 2>/dev/null || true)"  # "0|0.A|0.A.A"
[ -z "${HISTORY:-}" ] && HISTORY="$NODE"

save_state() {
  PAYLOAD_SET_CONFIG "$PAYLOAD_NAME" lang "$LANG_CODE" >/dev/null 2>&1 || true
  PAYLOAD_SET_CONFIG "$PAYLOAD_NAME" node "$NODE" >/dev/null 2>&1 || true
  PAYLOAD_SET_CONFIG "$PAYLOAD_NAME" hist "$HISTORY" >/dev/null 2>&1 || true
}

# --- UI helpers (Pager) ------------------------------------------------------

log_paragraph() {
  local text="$1"
  # split on \n to multiple LOG lines (more readable on-device)
  while IFS= read -r line; do
    LOG "$line"
  done <<< "$text"
}

menu() {
  LOG cyan "$(t ui.menu.title)"
  LOG ""
  LOG yellow "A) $(t ui.menu.resume)"
  LOG yellow "UP) $(t ui.menu.restart)"
  LOG yellow "RIGHT) $(t ui.menu.language)"
  LOG yellow "B) $(t ui.menu.exit)"
  local b
  b="$(WAIT_FOR_INPUT)"
  case "$b" in
    A) return 0 ;;
    UP)
      local r
      r="$(CONFIRMATION_DIALOG "$(t ui.restart.confirm)")" || return 0
      if [ "$r" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
        NODE="0"
        HISTORY="0"
        save_state
      fi
      return 0
      ;;
    RIGHT)
      local cur="${LANG_CODE}"
      local new
      new="$(TEXT_PICKER "$(t ui.lang.prompt)" "${cur}")" || return 0
      LANG_CODE="$new"
      LOCALE_FILE="${LOCALES_DIR}/${LANG_CODE}.lang"
      if [ ! -f "$LOCALE_FILE" ]; then
        ERROR_DIALOG "Missing locale: ${LANG_CODE}"
        LANG_CODE="it"
        LOCALE_FILE="${LOCALES_DIR}/it.lang"
      fi
      save_state
      return 0
      ;;
    B) exit 0 ;;
    *) return 0 ;;
  esac
}

render_node() {
  LOG cyan "$(t ui.title)"
  LOG ""
  log_paragraph "$(t "p.${NODE}.body")"
  LOG ""
  local c1 c2
  c1="$(t "p.${NODE}.c1")"
  c2="$(t "p.${NODE}.c2")"
  [ -z "$c1" ] && c1="(fine)"
  [ -z "$c2" ] && c2="(fine)"
  LOG yellow "▶ 1) ${c1}"
  LOG yellow "  2) ${c2}"
  LOG ""
  LOG "$(t ui.hint)"
}

choose_loop() {
  local sel=1
  while true; do
    render_node
    local b
    b="$(WAIT_FOR_INPUT)"
    case "$b" in
      UP|DOWN)
        if [ "$sel" = "1" ]; then sel=2; else sel=1; fi
        ;;
      LEFT)
        menu
        ;;
      B)
        # pop history (keep at least one)
        if [[ "$HISTORY" == *"|"* ]]; then
          HISTORY="${HISTORY%|*}"
          NODE="${HISTORY##*|}"
          save_state
        fi
        ;;
      A|RIGHT)
        local nxt_raw nxt

        nxt_raw="$(get_next "$NODE" "$sel")"

        if [[ "$sel" == "1" ]] && [[ "$NODE" == "FROGGER" || "$NODE" == "FROGGER.LOSE" ]] && [[ "$nxt_raw" == RANDOM:* ]]; then
          local roll
          roll="$(rand_range 7500000)"
          if [[ "$roll" -eq 42 ]]; then
            nxt="FROGGER.WIN"
          else
            nxt="$(resolve_target "$nxt_raw")"
          fi
        else
          nxt="$(resolve_target "$nxt_raw")"
        fi

        if [ -z "${nxt:-}" ]; then
          PROMPT "Fine."
          exit 0
        fi

        NODE="$nxt"
        HISTORY="${HISTORY}|${NODE}"
        save_state
        ;;
      *)
        ;;
    esac
    # Clear console-ish view: just add a separator.
    LOG "--------------------------------------------------"
  done
}

# --- sanity checks -----------------------------------------------------------

if [ ! -f "$STORY_TSV" ]; then
  ERROR_DIALOG "Missing story.tsv"
  exit 1
fi

choose_loop
