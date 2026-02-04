#!/bin/sh
# The Hacker Culture Trail - TSV/LANG engine (POSIX sh / BusyBox friendly)

set -u

STORY_FILE="${STORY_FILE:-./story/story.tsv}"
LANG_FILE="${LANG_FILE:-./locales/it.lang}"
SAVE_FILE="${SAVE_FILE:-/tmp/hct.save}"
HIST_FILE="${HIST_FILE:-/tmp/hct.hist}"

die() { printf "ERR: %s\n" "$*" >&2; exit 1; }

# ---------- IO ----------
INPUT_DEV() {
  # Prefer tty if present, else fallback to stdin
  if [ -r /dev/tty ] 2>/dev/null; then
    echo /dev/tty
  else
    # BusyBox typically has /dev/stdin, but /proc/self/fd/0 works too.
    if [ -r /dev/stdin ] 2>/dev/null; then
      echo /dev/stdin
    else
      echo /proc/self/fd/0
    fi
  fi
}

READ_LINE() {
  # usage: READ_LINE varname
  _var="$1"
  _in="$(INPUT_DEV)"
  # shellcheck disable=SC2162
  read "$_var" <"$_in" || return 1
  return 0
}

cls() { printf "\033[2J\033[H" 2>/dev/null || true; }

term_cols() {
  if command -v tput >/dev/null 2>&1; then
    c="$(tput cols 2>/dev/null || true)"
    [ -n "${c:-}" ] && echo "$c" && return
  fi
  echo 80
}

wrap() {
  cols="$(term_cols)"
  if command -v fold >/dev/null 2>&1; then
    fold -s -w "$cols"
  else
    cat
  fi
}

# ---------- normalizers ----------
# remove UTF-8 BOM (first line) and strip CRs
normalize_stream() {
  awk 'NR==1{sub(/^\xef\xbb\xbf/,"")} {gsub(/\r/,""); print}'
}

clean_token() {
  # remove CR and surrounding spaces (defensive)
  printf "%s" "$1" | tr -d '\r' | awk '{gsub(/^[ \t]+|[ \t]+$/,""); print}'
}

# ---------- lang ----------
lang_get() {
  key="$(clean_token "$1")"
  normalize_stream <"$LANG_FILE" | awk -v k="$key" '
    index($0, k "=")==1 {
      print substr($0, length(k)+2);
      found=1; exit
    }
    END { exit (found?0:1) }
  '
}

ui() {
  k="$1"
  v="$(lang_get "$k" 2>/dev/null || true)"
  if [ -n "${v:-}" ]; then
    printf "%b" "$v"
  else
    printf "%s" "$k"
  fi
}

p_body() { lang_get "p.$1.body" 2>/dev/null || true; }
p_c1()   { lang_get "p.$1.c1"   2>/dev/null || true; }
p_c2()   { lang_get "p.$1.c2"   2>/dev/null || true; }

# ---------- story ----------
story_get_row() {
  node="$(clean_token "$1")"
  normalize_stream <"$STORY_FILE" | awk -F'\t' -v n="$node" '
    {
      # strip CR already done, but keep robust
      gsub(/\r/,"",$1); gsub(/\r/,"",$2); gsub(/\r/,"",$3);
    }
    $1==n { print $2 "\t" $3; found=1; exit }
    END { exit (found?0:1) }
  '
}

node_exists() {
  node="$(clean_token "$1")"
  normalize_stream <"$STORY_FILE" | awk -F'\t' -v n="$node" '
    { gsub(/\r/,"",$1) }
    $1==n { found=1 }
    END { exit (found?0:1) }
  '
}

# RANDOM:NAME@w|NAME2@w2...
pick_random() {
  spec="$1"
  sum=0

  oldIFS="$IFS"; IFS='|'
  for part in $spec; do
    IFS="$oldIFS"
    name="${part%@*}"
    w="${part#*@}"
    case "$w" in ''|*[!0-9]*) w=1 ;; esac
    sum=$((sum + w))
    IFS='|'
  done
  IFS="$oldIFS"
  [ "$sum" -gt 0 ] || { printf "%s" "${spec%%|*}"; return 0; }

  if [ -r /dev/urandom ] && command -v od >/dev/null 2>&1; then
    r="$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' ')"
  else
    r=$(( ( $(date +%s 2>/dev/null || echo 12345) + $$ ) % 65536 ))
  fi
  pick=$(( (r % sum) + 1 ))

  acc=0
  oldIFS="$IFS"; IFS='|'
  for part in $spec; do
    IFS="$oldIFS"
    name="$(clean_token "${part%@*}")"
    w="${part#*@}"
    case "$w" in ''|*[!0-9]*) w=1 ;; esac
    acc=$((acc + w))
    if [ "$pick" -le "$acc" ]; then
      printf "%s" "$name"
      return 0
    fi
    IFS='|'
  done
  IFS="$oldIFS"
  printf "%s" "${spec%%|*}"
}

resolve_next() {
  raw="$(clean_token "$1")"
  [ -n "${raw:-}" ] || { printf ""; return 0; }
  case "$raw" in
    RANDOM:*) pick_random "${raw#RANDOM:}" ;;
    *) printf "%s" "$raw" ;;
  esac
}

# ---------- save / history ----------
hist_push() { printf "%s\n" "$(clean_token "$1")" >>"$HIST_FILE" 2>/dev/null || true; }

hist_pop() {
  [ -f "$HIST_FILE" ] || return 1
  last="$(tail -n 1 "$HIST_FILE" 2>/dev/null || true)"
  last="$(clean_token "$last")"
  [ -n "${last:-}" ] || return 1

  # remove last line
  tmp="${HIST_FILE}.tmp.$$"
  awk 'NR>1{print prev} {prev=$0}' "$HIST_FILE" >"$tmp" 2>/dev/null && mv "$tmp" "$HIST_FILE"
  printf "%s" "$last"
}

save_set() { printf "%s\n" "$(clean_token "$1")" >"$SAVE_FILE" 2>/dev/null || true; }
save_get() { [ -f "$SAVE_FILE" ] && head -n 1 "$SAVE_FILE" 2>/dev/null | tr -d '\r' || true; }
save_clear() { rm -f "$SAVE_FILE" "$HIST_FILE" 2>/dev/null || true; }

# ---------- UI ----------
menu_screen() {
  cls
  printf "%s\n\n" "$(ui ui.menu.title)" | wrap
  printf "1) %s\n" "$(ui ui.menu.resume)" | wrap
  printf "2) %s\n" "$(ui ui.menu.restart)" | wrap
  printf "3) %s\n\n" "$(ui ui.menu.exit)" | wrap
  printf "> "
  READ_LINE ans || { echo ""; return 0; }

  case "$ans" in
    1) echo "__RESUME__" ;;
    2)
      printf "%s [y/N] " "$(ui ui.restart.confirm)" | wrap
      READ_LINE c || c="n"
      case "$c" in y|Y) save_clear; echo "__RESTART__" ;; *) echo "" ;; esac
      ;;
    3) echo "__EXIT__" ;;
    *) echo "" ;;
  esac
}

show_node() {
  node="$1"
  node="$(clean_token "$node")"
  cls

  printf "%s\n\n" "$(ui ui.title)" | wrap
  body="$(p_body "$node")"
  if [ -n "${body:-}" ]; then
    printf "%b\n" "$body" | wrap
  else
    printf "[missing text: p.%s.body]\n" "$node" | wrap
  fi
  printf "\n"

  c1="$(p_c1 "$node")"
  c2="$(p_c2 "$node")"

  row="$(story_get_row "$node" 2>/dev/null || true)"
  next1="$(printf "%s" "$row" | awk -F'\t' '{print $1}' | tr -d '\r')"
  next2="$(printf "%s" "$row" | awk -F'\t' '{print $2}' | tr -d '\r')"

  if [ -n "${c1:-}" ]; then
    if [ -n "${next1:-}" ]; then printf "1) %b\n" "$c1" | wrap
    else printf "1) %b (N/A)\n" "$c1" | wrap
    fi
  fi

  if [ -n "${c2:-}" ]; then
    if [ -n "${next2:-}" ]; then printf "2) %b\n" "$c2" | wrap
    else printf "2) %b (N/A)\n" "$c2" | wrap
    fi
  fi

  printf "\n[m=menu, b=back] > "
}

# ---------- main ----------
main() {
  [ -r "$STORY_FILE" ] || die "Cannot read story file: $STORY_FILE"
  [ -r "$LANG_FILE" ] || die "Cannot read lang file: $LANG_FILE"

  if node_exists "START"; then
    START_NODE="START"
  elif node_exists "0"; then
    START_NODE="0"
  else
    START_NODE="$(normalize_stream <"$STORY_FILE" | awk -F'\t' 'NF{print $1; exit}')"
    START_NODE="$(clean_token "$START_NODE")"
    [ -n "${START_NODE:-}" ] || die "No nodes in story.tsv"
  fi

  current="$(save_get)"
  current="$(clean_token "$current")"
  [ -n "${current:-}" ] || current="$START_NODE"

  while :; do
    show_node "$current"
    READ_LINE choice || choice=""

    case "$choice" in
      m|M)
        res="$(menu_screen)"
        case "$res" in
          "__EXIT__") exit 0 ;;
          "__RESTART__") current="$START_NODE"; save_set "$current";;
          "__RESUME__"|"") : ;;
        esac
        ;;
      b|B)
        prev="$(hist_pop 2>/dev/null || true)"
        if [ -n "${prev:-}" ]; then
          current="$prev"
          save_set "$current"
        fi
        ;;
      1|2)
        row="$(story_get_row "$current" 2>/dev/null || true)"
        raw1="$(printf "%s" "$row" | awk -F'\t' '{print $1}')"
        raw2="$(printf "%s" "$row" | awk -F'\t' '{print $2}')"

        if [ "$choice" = "1" ]; then next="$(resolve_next "$raw1")"
        else next="$(resolve_next "$raw2")"
        fi

        if [ -n "${next:-}" ]; then
          hist_push "$current"
          current="$next"
          save_set "$current"
        fi
        ;;
      *) : ;;
    esac
  done
}

main "$@"