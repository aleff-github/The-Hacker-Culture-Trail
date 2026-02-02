export class I18n {
  constructor() {
    this.fallback = {};
    this.dict = {};
  }

  async load(fallbackUrl, url) {
    this.fallback = await this.#fetchJson(fallbackUrl);
    if (url && url !== fallbackUrl) {
      try {
        this.dict = await this.#fetchJson(url);
      } catch {
        this.dict = {};
      }
    } else {
      this.dict = {};
    }
  }

  t(key) {
    return (this.dict && this.dict[key]) || (this.fallback && this.fallback[key]) || this.fallback["ui.missing"] || "[missing]";
  }

  async #fetchJson(url) {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) throw new Error(`Failed to load ${url}: ${r.status}`);
    return await r.json();
  }
}
