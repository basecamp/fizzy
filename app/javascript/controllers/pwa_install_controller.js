import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.checkAvailability()

    window.addEventListener("pwa-install:available", this.checkAvailability)

    if (window.matchMedia('(display-mode: standalone)').matches) {
      this.element.hidden = true
    }
  }

  disconnect() {
    window.removeEventListener("pwa-install:available", this.checkAvailability)
  }

  checkAvailability = () => {
    if (window.deferredPrompt) {
      const ua = navigator.userAgent
      if (/Android/i.test(ua) && /Chrome/i.test(ua)) {
        this.element.hidden = false
      }
    }
  }

  async install() {
    if (!window.deferredPrompt) return

    window.deferredPrompt.prompt()

    const { outcome } = await window.deferredPrompt.userChoice

    if (outcome === "accepted") {
      window.deferredPrompt = null
      this.element.hidden = true
    }
  }
}
