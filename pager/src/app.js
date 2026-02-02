import { Engine } from "./engine.js";
import { I18n } from "./i18n.js";

const $ = (id) => document.getElementById(id);

const appTitle = $("appTitle");
const appSub = $("appSub");
const storyText = $("storyText");
const choicesEl = $("choices");
const footerText = $("footerText");
const backBtn = $("backBtn");
const restartBtn = $("restartBtn");
const langSelect = $("langSelect");

let story = null;
let engine = null;
let i18n = new I18n();

let selectedIndex = 0;
let isTyping = false;
let typingCancel = null;

function getLangFromUrl() {
  const p = new URLSearchParams(location.search);
  const l = p.get("lang");
  return l && /^[a-z]{2}$/i.test(l) ? l.toLowerCase() : null;
}

async function loadStory() {
  const r = await fetch("./story/story.graph.json", { cache: "no-store" });
  story = await r.json();
  engine = new Engine(story);
  engine.loadState();

  const langFromUrl = getLangFromUrl();
  if (langFromUrl) engine.setLang(langFromUrl);

  langSelect.value = engine.state.lang;
  await loadLocales(engine.state.lang);

  render();
  attachEvents();
}

async function loadLocales(lang) {
  // always load IT as fallback
  await i18n.load("./locales/it.json", `./locales/${lang}.json`);
  document.documentElement.lang = lang;
  appTitle.textContent = i18n.t("app.title");
  appSub.textContent = i18n.t("ui.choiceHint") + " · " + i18n.t("ui.saveHint");
  backBtn.title = i18n.t("ui.back");
  restartBtn.title = i18n.t("ui.restart");
}

function clearChoices() {
  choicesEl.innerHTML = "";
  selectedIndex = 0;
}

function splitParagraphs(raw) {
  // keep the author's whitespace vibe, but turn double-newlines into paragraphs
  const blocks = raw.replace(/\r\n/g, "\n").split(/\n\s*\n/);
  return blocks.map(b => b.trim()).filter(Boolean);
}

function setSelected(idx) {
  const btns = [...choicesEl.querySelectorAll("button.choice")];
  if (btns.length === 0) return;
  selectedIndex = Math.max(0, Math.min(idx, btns.length - 1));
  btns.forEach((b, i) => b.classList.toggle("selected", i === selectedIndex));
  btns[selectedIndex].focus({ preventScroll: true });
}

function stopTyping() {
  if (typingCancel) typingCancel();
  typingCancel = null;
  isTyping = false;
}

function typeInto(el, html) {
  stopTyping();
  isTyping = true;

  el.innerHTML = "";
  const tmp = document.createElement("div");
  tmp.innerHTML = html;

  const fullText = tmp.textContent || "";
  let i = 0;

  const tick = () => {
    if (!isTyping) return;
    i += 2; // speed
    el.textContent = fullText.slice(0, i);
    if (i < fullText.length) {
      requestAnimationFrame(tick);
    } else {
      isTyping = false;
      // restore HTML formatting at the end
      el.innerHTML = html;
    }
  };

  requestAnimationFrame(tick);
  typingCancel = () => { isTyping = false; el.innerHTML = html; };
}

function render() {
  const pid = engine.state.current;
  const p = engine.currentPassage();

  footerText.textContent = `${pid}`;

  backBtn.disabled = !engine.canGoBack();

  const bodyKey = p.bodyKey;
  const rawBody = i18n.t(bodyKey) || "";
  const paras = splitParagraphs(rawBody);

  const html = paras.map(t => `<p>${escapeHtml(t)}</p>`).join("");
  typeInto(storyText, html);

  clearChoices();

  (p.choices || []).forEach((c, idx) => {
    const b = document.createElement("button");
    b.className = "choice";
    b.innerHTML = `<span class="hint">${idx === 0 ? "◀" : idx === 1 ? "▶" : "•"}</span>${escapeHtml(i18n.t(c.labelKey))}`;
    b.addEventListener("click", () => {
      stopTyping();
      engine.goto(c.to);
      render();
    });
    choicesEl.appendChild(b);
  });

  setSelected(0);
}

function escapeHtml(s) {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function attachEvents() {
  restartBtn.addEventListener("click", () => {
    stopTyping();
    engine.restart();
    render();
  });

  backBtn.addEventListener("click", () => {
    stopTyping();
    engine.back();
    render();
  });

  langSelect.addEventListener("change", async () => {
    const lang = langSelect.value;
    engine.setLang(lang);
    await loadLocales(lang);
    render();
  });

  document.addEventListener("keydown", async (e) => {
    const btns = [...choicesEl.querySelectorAll("button.choice")];

    if (e.key === "Escape") {
      stopTyping();
      return;
    }
    if (e.key === "r" || e.key === "R") {
      stopTyping();
      engine.restart();
      render();
      return;
    }
    if (e.key === "Backspace" || e.key === "b" || e.key === "B") {
      if (engine.canGoBack()) {
        stopTyping();
        engine.back();
        render();
      }
      return;
    }
    if (btns.length === 0) return;

    if (e.key === "ArrowLeft") {
      setSelected(0);
      e.preventDefault();
      return;
    }
    if (e.key === "ArrowRight") {
      setSelected(1 < btns.length ? 1 : 0);
      e.preventDefault();
      return;
    }
    if (e.key === "ArrowUp") {
      setSelected(selectedIndex - 1);
      e.preventDefault();
      return;
    }
    if (e.key === "ArrowDown") {
      setSelected(selectedIndex + 1);
      e.preventDefault();
      return;
    }
    if (e.key === "Enter") {
      stopTyping();
      btns[selectedIndex].click();
      e.preventDefault();
      return;
    }
  });
}

// boot
appTitle.textContent = "…";
appSub.textContent = "…";
storyText.textContent = "…";
footerText.textContent = "…";

loadStory().catch(err => {
  console.error(err);
  storyText.textContent = "Errore di caricamento. Controlla la console.";
});
