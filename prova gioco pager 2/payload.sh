#!/bin/bash
# Title: Labir:contentReference[oaicite:8]{index=8}ion: Un librogame a due scelte con tasti A/B
# Author: Il Tuo Nome <tuo@email>

set -u
:contentReference[oaicite:9]{index=9}nto_demo"
SAVE_KEY="node"

# Riprendi da dove eri rimasto (se es:contentReference[oaicite:10]{index=10}
node="$(PAYLOAD_GET_CONFIG "$PAYLOAD_NAME" "$SAVE_KEY" 2>/dev/null)" || node="CASA"  # :contentReference[oaicite:11]{index=11}

choose_ab() {
  # Mostra un testo e aspetta A o B. Ritorna "A" o "B".
  PROMPT "$1" || exit 0                           # :contentReference[oaicite:12]{index=12}
  local btn
  btn="$(WAIT_FOR_INPUT)" || exit 0               # :contentReference[oaicite:13]{index=13}
  case "$btn" in
    A|B) echo "$btn" ;;
    *) echo "" ;;  # ignora altri tasti
  esac
}

save_node() {
  PAYLOAD_SET_CONFIG "$PAYLOAD_NAME" "$SAVE_KEY" "$node" >/dev/null 2>&1 || true  # :contentReference[oaicite:14]{index=14}
}

while true; do
  case "$node" in
    CASA)
      c="$(choose_ab "Sei a CASA.\nA=GIARDINO  B=BALCONE")"
      [ -z "$c" ] && continue
      if [ "$c" = "A" ]; then node="GIARDINO"; else node="BALCONE"; fi
      save_node
      ;;

    GIARDINO)
      c="$(choose_ab "Sei in GIARDINO.\nA=TORNA A CASA  B=CAPANNO")"
      [ -z "$c" ] && continue
      if [ "$c" = "A" ]; then node="CASA"; else node="CAPANNO"; fi
      save_node
      ;;

    BALCONE)
      c="$(choose_ab "Sei sul BALCONE.\nA=SCENDI IN GIARDINO  B=ENTRA IN CASA")"
      [ -z "$c" ] && continue
      if [ "$c" = "A" ]; then node="GIARDINO"; else node="CASA"; fi
      save_node
      ;;

    CAPANNO)
      c="$(choose_ab "Nel CAPANNO trovi una scatola.\nA=APRILA  B=LASCIA PERDERE")"
      [ -z "$c" ] && continue
      if [ "$c" = "A" ]; then node="FINE_BUONA"; else node="FINE_NEUTRA"; fi
      save_node
      ;;

    FINE_BUONA)
      c="$(choose_ab "Hai trovato la chiave segreta. Fine!\nA=RIPARTI  B=ESCI")"
      [ -z "$c" ] && continue
      if [ "$c" = "A" ]; then node="CASA"; else break; fi
      save_node
      ;;

    FINE_NEUTRA)
      c="$(choose_ab "Ti annoi e te ne vai. Fine.\nA=RIPARTI  B=ESCI")"
      [ -z "$c" ] && continue
      if [ "$c" = "A" ]; then node="CASA"; else break; fi
      save_node
      ;;

    *)
      node="CASA"
      save_node
      ;;
  esac
done

exit 0