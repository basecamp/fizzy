import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lightBtn", "darkBtn", "autoBtn"]

  connect() {
    this.applyStoredTheme()
    this.updateButtons()
  }

  setLight() {
    this.setTheme("light")
    document.documentElement.setAttribute("data-theme", "light")
    this.updateButtons()
  }

  setDark() {
    this.setTheme("dark")
    document.documentElement.setAttribute("data-theme", "dark")
    this.updateButtons()
  }

  setAuto() {
    this.setTheme("auto")
    document.documentElement.removeAttribute("data-theme")
    this.updateButtons()
  }

  setTheme(theme) {
    localStorage.setItem("theme", theme)
  }

  applyStoredTheme() {
    const storedTheme = localStorage.getItem("theme") || "auto"

    if (storedTheme === "light") {
      document.documentElement.setAttribute("data-theme", "light")
    } else if (storedTheme === "dark") {
      document.documentElement.setAttribute("data-theme", "dark")
    } else {
      // auto - don't set data-theme, let CSS media query handle it
      document.documentElement.removeAttribute("data-theme")
    }
  }

  updateButtons() {
    const storedTheme = localStorage.getItem("theme") || "auto"

    // Reset all buttons
    if (this.hasLightBtnTarget) this.lightBtnTarget.removeAttribute("aria-selected")
    if (this.hasDarkBtnTarget) this.darkBtnTarget.removeAttribute("aria-selected")
    if (this.hasAutoBtnTarget) this.autoBtnTarget.removeAttribute("aria-selected")

    // Highlight active button
    if (storedTheme === "light" && this.hasLightBtnTarget) {
      this.lightBtnTarget.setAttribute("aria-selected", "true")
    } else if (storedTheme === "dark" && this.hasDarkBtnTarget) {
      this.darkBtnTarget.setAttribute("aria-selected", "true")
    } else if (this.hasAutoBtnTarget) {
      this.autoBtnTarget.setAttribute("aria-selected", "true")
    }
  }
}
