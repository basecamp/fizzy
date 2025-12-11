import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lightButton", "darkButton", "autoButton"]

  connect() {
    this.#applyStoredTheme()
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

  set #theme(theme) {
    localStorage.setItem("theme", theme)

    if (theme === "auto") {
      document.documentElement.removeAttribute("data-theme")
    } else {
      document.documentElement.setAttribute("data-theme", theme)
    }

    this.#updateButtons()
  }

  #applyStoredTheme() {
    this.#theme = this.#storedTheme
  }

  #updateButtons() {
    const storedTheme = this.#storedTheme

    if (this.hasLightButtonTarget) { this.lightButtonTarget.checked = (storedTheme === "light") }
    if (this.hasDarkButtonTarget)  { this.darkButtonTarget.checked  = (storedTheme === "dark") }
    if (this.hasAutoButtonTarget)  { this.autoButtonTarget.checked  = (storedTheme !== "light" && storedTheme !== "dark") }
  }
}
