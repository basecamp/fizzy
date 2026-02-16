import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (window.PublicKeyCredential?.isConditionalMediationAvailable) {
      this.attemptConditionalMediation()
    }
  }

  disconnect() {
    this.abortController?.abort()
  }

  async attemptConditionalMediation() {
    if (!await PublicKeyCredential.isConditionalMediationAvailable()) return

    this.abortController = new AbortController()

    try {
      const credential = await navigator.credentials.get({
        publicKey: {
          challenge: crypto.getRandomValues(new Uint8Array(32)),
          rpId: window.location.hostname
        },
        mediation: "conditional",
        signal: this.abortController.signal
      })

      console.log("Passkey selected:", credential)
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Passkey error:", error)
      }
    }
  }
}
