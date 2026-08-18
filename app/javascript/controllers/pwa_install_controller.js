import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.checkAvailability()

    window.addEventListener("pwa-install:available", this.checkAvailability)

    if (window.matchMedia('(display-mode: standalone)').matches) {
      this.element.classList.add("hidden")
    }
  }

  disconnect() {
    window.removeEventListener("pwa-install:available", this.checkAvailability)
  }

  checkAvailability = () => {
    if (window.deferredPrompt) {
      this.element.classList.remove("hidden")
    }
  }

  async install() {
    if (!window.deferredPrompt) return

    window.deferredPrompt.prompt()

    const { outcome } = await window.deferredPrompt.userChoice

    if (outcome === "accepted") {
      window.deferredPrompt = null
      this.element.classList.add("hidden")
    }
  }
}
