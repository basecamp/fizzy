import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { publicKey: Object }
  static targets = ["clientDataJSON", "attestationObject"]

  async create(event) {
    event.preventDefault()

    try {
      const publicKey = this.prepareOptions(this.publicKeyValue)
      const credential = await navigator.credentials.create({ publicKey })
      this.submitCredential(credential)
    } catch (error) {
      if (error.name !== "AbortError" && error.name !== "NotAllowedError") {
        console.error("Registration failed:", error)
      }
    }
  }

  submitCredential(credential) {
    this.clientDataJSONTarget.value = new TextDecoder().decode(credential.response.clientDataJSON)
    this.attestationObjectTarget.value = this.bufferToBase64url(credential.response.attestationObject)

    for (const transport of credential.response.getTransports?.() || []) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "credential[transports][]"
      input.value = transport
      this.element.appendChild(input)
    }

    this.element.requestSubmit()
  }

  prepareOptions(options) {
    return {
      ...options,
      challenge: this.base64urlToBuffer(options.challenge),
      user: { ...options.user, id: this.base64urlToBuffer(options.user.id) },
      excludeCredentials: (options.excludeCredentials || []).map(cred => ({
        ...cred,
        id: this.base64urlToBuffer(cred.id)
      }))
    }
  }

  base64urlToBuffer(base64url) {
    const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
    const padding = "=".repeat((4 - base64.length % 4) % 4)
    const binary = atob(base64 + padding)
    return Uint8Array.from(binary, c => c.charCodeAt(0)).buffer
  }

  bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer)
    const binary = String.fromCharCode(...bytes)
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
  }
}
