Labirinto (librogame) per WiFi Pineapple Pager - v1.1
====================================================

Questa versione aggiunge:
- log dettagliato su /root/loot/labirinto_librogame_debug.log
- storia all-ASCII (evita problemi con caratteri UTF-8 nelle finestre PROMPT)
- controlli/diagnostica per nodi mancanti

Se dal Pager "si blocca" senza spiegazioni:
1) Avvia una volta il payload dal Pager.
2) Poi via SSH leggi il log:
   cat /root/loot/labirinto_librogame_debug.log
   (oppure: tail -n 200 /root/loot/labirinto_librogame_debug.log)

Nota su story.tsv
- Deve essere TSV vero (tab tra colonne).
- Evita CRLF (Windows). Se sospetti CRLF:
  sed -i 's/\r$//' story.tsv
- Evita virgolette curve “ ”, apostrofi strani, emoji.
