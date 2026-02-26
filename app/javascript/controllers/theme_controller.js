import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lightButton", "darkButton", "autoButton"]

  #mediaQuery
  #handleSystemThemeChange

  connect() {
    this.#mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.#handleSystemThemeChange = () => this.#applyStoredTheme()
    this.#mediaQuery.addEventListener("change", this.#handleSystemThemeChange)
    this.#applyStoredTheme()
  }

  disconnect() {
    this.#mediaQuery.removeEventListener("change", this.#handleSystemThemeChange)
  }

  setLight() {
    this.#theme = "light"
  }

  setDark() {
    this.#theme = "dark"
  }

  setAuto() {
    this.#theme = "auto"
  }

  get #storedTheme() {
    return localStorage.getItem("theme") || "auto"
  }

  get #resolvedTheme() {
    const stored = this.#storedTheme
    if (stored === "light" || stored === "dark") return stored
    return this.#mediaQuery.matches ? "dark" : "light"
  }

  set #theme(theme) {
    localStorage.setItem("theme", theme)

    const resolved = this.#resolvedTheme
    const currentTheme = document.documentElement.dataset.theme
    const hasChanged = currentTheme !== resolved

    const prefersReducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
    const animate = hasChanged && !prefersReducedMotion

    const applyTheme = () => {
      document.documentElement.dataset.theme = resolved
      this.#updateThemeColor()
      this.#updateButtons()
    }

    if (animate && document.startViewTransition) {
      document.startViewTransition(applyTheme)
    } else {
      applyTheme()
    }
  }

  #applyStoredTheme() {
    this.#theme = this.#storedTheme
  }

  #updateThemeColor() {
    const lightMeta = document.getElementById("theme-color-light")
    const darkMeta = document.getElementById("theme-color-dark")
    if (!lightMeta || !darkMeta) return

    const stored = this.#storedTheme

    if (stored === "light" || stored === "dark") {
      lightMeta.media = stored === "light" ? "all" : "not all"
      darkMeta.media = stored === "dark" ? "all" : "not all"
    } else {
      lightMeta.media = "(prefers-color-scheme: light)"
      darkMeta.media = "(prefers-color-scheme: dark)"
    }
  }

  #updateButtons() {
    const storedTheme = this.#storedTheme

    if (this.hasLightButtonTarget) { this.lightButtonTarget.checked = (storedTheme === "light") }
    if (this.hasDarkButtonTarget)  { this.darkButtonTarget.checked  = (storedTheme === "dark") }
    if (this.hasAutoButtonTarget)  { this.autoButtonTarget.checked  = (storedTheme !== "light" && storedTheme !== "dark") }
  }
}
