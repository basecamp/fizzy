import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.deferredPrompt = null
    window.addEventListener("beforeinstallprompt", this.handleBeforeInstallPrompt)
    
    // Check if app is already installed
    if (window.matchMedia('(display-mode: standalone)').matches) {
      this.element.classList.add("hidden")
    }
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.handleBeforeInstallPrompt)
  }

  handleBeforeInstallPrompt = (e) => {
    // Prevent the mini-infobar from appearing on mobile
    e.preventDefault()
    // Stash the event so it can be triggered later.
    this.deferredPrompt = e
    // Update UI notify the user they can install the PWA
    this.element.classList.remove("hidden")
  }

  async install() {
    if (!this.deferredPrompt) return

    // Show the install prompt
    this.deferredPrompt.prompt()
    
    // Wait for the user to respond to the prompt
    const { outcome } = await this.deferredPrompt.userChoice
    console.log(`User response to the install prompt: ${outcome}`)
    
    // We've used the prompt, and can't use it again, throw it away
    this.deferredPrompt = null
    
    // Hide the install button
    this.element.classList.add("hidden")
  }
}
