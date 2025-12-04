import { Controller } from "@hotwired/stimulus"

const THEME_DARK = "dark"
const THEME_LIGHT = "light"

export default class extends Controller {
  static targets = ["label"]
  static values = { storageKey: { type: String, default: "theme-preference" } }

  connect() {
    this.applyTheme()
    this.updateAllLabels()
    document.addEventListener("turbo:frame-load", () => this.updateAllLabels())
    document.addEventListener("turbo:load", () => this.updateAllLabels())
  }

  toggle() {
    const currentTheme = this.getCurrentTheme()
    const newTheme = currentTheme === THEME_DARK ? THEME_LIGHT : THEME_DARK
    this.setTheme(newTheme)
    this.updateAllLabels()
  }

  getCurrentTheme() {
    const savedTheme = localStorage.getItem(this.storageKeyValue)
    if (savedTheme === THEME_LIGHT || savedTheme === THEME_DARK) {
      return savedTheme
    }
    return this.getSystemPreference()
  }

  applyTheme() {
    const theme = this.getCurrentTheme()
    this.setTheme(theme)
  }

  setTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    localStorage.setItem(this.storageKeyValue, theme)
  }

  updateAllLabels() {
    const theme = this.getCurrentTheme()
    const labelText = this.#labelTextFor(theme)
    document.querySelectorAll('[data-theme-target="label"]').forEach(label => {
      label.textContent = labelText
    })
  }

  getSystemPreference() {
    if (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) {
      return THEME_DARK
    }
    return THEME_LIGHT
  }

  #labelTextFor(theme) {
    if (theme === THEME_DARK) {
      return "Dark mode"
    } else {
      return "Light mode"
    }
  }
}

