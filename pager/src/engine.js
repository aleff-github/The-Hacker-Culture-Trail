export class Engine {
  constructor(story) {
    this.story = story;
    this.state = {
      lang: "it",
      current: story.start,
      history: []
    };
  }

  loadState() {
    try {
      const raw = localStorage.getItem("hct_state");
      if (!raw) return;
      const s = JSON.parse(raw);
      if (s && s.current && this.story.passages[s.current]) {
        this.state = {
          lang: typeof s.lang === "string" ? s.lang : "it",
          current: s.current,
          history: Array.isArray(s.history) ? s.history.filter(id => this.story.passages[id]) : []
        };
      }
    } catch {}
  }

  saveState() {
    try {
      localStorage.setItem("hct_state", JSON.stringify(this.state));
    } catch {}
  }

  setLang(lang) {
    this.state.lang = lang;
    this.saveState();
  }

  restart() {
    this.state.current = this.story.start;
    this.state.history = [];
    this.saveState();
  }

  canGoBack() {
    return this.state.history.length > 0;
  }

  back() {
    if (!this.canGoBack()) return;
    this.state.current = this.state.history.pop();
    this.saveState();
  }

  goto(nextId) {
    if (!this.story.passages[nextId]) {
      console.warn("Unknown passage:", nextId);
      return;
    }
    this.state.history.push(this.state.current);
    this.state.current = nextId;
    this.saveState();
  }

  currentPassage() {
    return this.story.passages[this.state.current];
  }
}
