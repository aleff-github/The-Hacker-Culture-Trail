# Hacker Culture Trail — Pager base

Questa è una base **minimale ma solida** per eseguire *The Hacker Culture Trail* come “pager game” (testo + due scelte),
con **testi esternalizzati** in JSON per supportare più lingue.

## Struttura

- `index.html` + `assets/styles.css` → UI terminal-style (leggera, mobile-friendly)
- `story/story.graph.json` → grafo della storia (ID passaggi + destinazioni delle scelte) **senza testi**
- `locales/it.json` → tutti i testi (corpo + etichette scelte + UI) in italiano
- `locales/en.json` → esempio (parziale) per iniziare l’inglese
- `src/` → engine + i18n + app

## Come si usa

Apri `index.html` con un server locale (consigliato) per evitare limitazioni di `fetch()`.

Esempi:
- `python -m http.server 8080` e poi vai su `http://localhost:8080`
- lingua: `?lang=en` oppure menu in alto a destra.

Controlli:
- ← / → seleziona le prime due scelte
- ↑ / ↓ cambia selezione
- Invio conferma
- Backspace o B torna indietro
- R ricomincia
- Esc salta l’effetto “typewriter” (mostra subito il testo)

## Localizzazione

Aggiungi un file come `locales/fr.json` e metti dentro:
- tutte le chiavi UI (puoi copiarle da `it.json`)
- le chiavi `p.<PASSAGE_ID>.body` e `p.<PASSAGE_ID>.c1`, `c2`, …

Se una chiave manca nella lingua selezionata, il sistema fa fallback su `it.json`.

## Rigenerare i JSON dal .twee

`tools/compile_twee.py` è un compilatore semplice:

```bash
python tools/compile_twee.py "../The Hacker Culture Trail.twee" --out dist --lang it
```

Genera `dist/story/story.graph.json` e `dist/locales/it.json`.

## Nota

Questo è volutamente una base “pulita”: non interpreta macro SugarCube, non gestisce variabili/condizionali.
Se vuoi, il prossimo step è aggiungere un layer di scripting (per gestire Curiosità/Padronanza ecc.) mantenendo la stessa struttura di localizzazione.
