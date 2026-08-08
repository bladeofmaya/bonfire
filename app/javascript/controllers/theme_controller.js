import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "bonfire-theme"
const THEMES = [ "system", "light", "dark" ]

export default class extends Controller {
  static targets = [ "select" ]

  connect() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: light)")
    this.systemThemeDidChange = () => this.#apply(this.preference)
    this.mediaQuery.addEventListener("change", this.systemThemeDidChange)
    this.#apply(this.preference)
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.systemThemeDidChange)
  }

  selectTargetConnected(select) {
    select.value = this.preference
  }

  change({ target }) {
    const preference = THEMES.includes(target.value) ? target.value : "system"

    try {
      if (preference === "system") {
        localStorage.removeItem(STORAGE_KEY)
      } else {
        localStorage.setItem(STORAGE_KEY, preference)
      }
    } catch (_error) {
      // Browsers may disable localStorage in hardened privacy modes.
    }

    this.#apply(preference)
  }

  get preference() {
    try {
      const storedTheme = localStorage.getItem(STORAGE_KEY)
      return THEMES.includes(storedTheme) ? storedTheme : "system"
    } catch (_error) {
      return "system"
    }
  }

  #apply(preference) {
    const theme = preference === "system" ? (this.mediaQuery.matches ? "light" : "dark") : preference

    document.documentElement.dataset.theme = theme
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", theme === "light" ? "#fdf8f0" : "#181510")
    this.selectTargets.forEach((select) => select.value = preference)
  }
}
