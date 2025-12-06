import { Controller } from "@hotwired/stimulus"

const THEME_DARK = "dark"
const THEME_LIGHT = "light"
const THEME_SYSTEM = "system"
const STORAGE_KEY = "theme-preference"

export default class extends Controller {
  static targets = ["label", "option"]
  static values = { storageKey: { type: String, default: STORAGE_KEY } }

  connect() {
    this.applyTheme()
    this.updateAllLabels()
    document.addEventListener("turbo:frame-load", () => this.updateAllLabels())
    document.addEventListener("turbo:load", () => {
      this.applyTheme()
      this.updateAllLabels()
    })
  }

  selectLight() { this.#select(THEME_LIGHT) }
  selectDark() { this.#select(THEME_DARK) }
  selectSystem() { this.#select(THEME_SYSTEM) }

  getCurrentTheme() {
    const preference = this.#getPreference()
    return this.#resolveTheme(preference)
  }

  applyTheme() {
    const preference = this.#getPreference()
    this.setTheme(preference)
  }

  setTheme(preference) {
    if (preference === THEME_SYSTEM) {
      document.documentElement.removeAttribute("data-theme")
      localStorage.setItem(this.storageKeyValue, THEME_SYSTEM)
    } else {
      document.documentElement.setAttribute("data-theme", preference)
      localStorage.setItem(this.storageKeyValue, preference)
    }
  }

  updateAllLabels() {
    const preference = this.#getPreference()
    const resolvedTheme = this.#resolveTheme(preference)
    const labelText = this.#labelTextFor(resolvedTheme)

    this.labelTargets.forEach(label => {
      label.textContent = labelText
    })

    this.optionTargets.forEach(option => {
      const value = option.dataset.themeOptionValue
      const isCurrent = value === preference
      option.setAttribute("aria-checked", isCurrent ? "true" : "false")
      option.classList.toggle("is-current", isCurrent)
    })
  }

  #select(preference) {
    this.setTheme(preference)
    this.updateAllLabels()
  }

  #getPreference() {
    const saved = localStorage.getItem(this.storageKeyValue)
    if ([THEME_LIGHT, THEME_DARK, THEME_SYSTEM].includes(saved)) {
      return saved
    }
    return THEME_SYSTEM
  }

  #resolveTheme(preference) {
    if (preference === THEME_SYSTEM) {
      return this.#systemPreference()
    }
    return preference
  }

  #systemPreference() {
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

