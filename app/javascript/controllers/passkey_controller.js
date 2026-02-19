import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { publicKey: Object, url: String, csrfToken: String }

  #abortController

  connect() {
    this.#attemptConditionalMediation()
  }

  disconnect() {
    this.#abortController?.abort()
  }

  async #attemptConditionalMediation() {
    if (!await PublicKeyCredential?.isConditionalMediationAvailable?.()) return

    this.#abortController = new AbortController()

    try {
      const credential = await navigator.credentials.get({
        publicKey: this.#prepareOptions(this.publicKeyValue),
        mediation: "conditional",
        signal: this.#abortController.signal
      })

      this.#submitAssertion(credential)
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Passkey error:", error)
      }
    }
  }

  #submitAssertion(credential) {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.urlValue
    form.style.display = "none"

    const fields = {
      authenticity_token: this.csrfTokenValue,
      "passkey[id]": credential.id,
      "passkey[client_data_json]": new TextDecoder().decode(credential.response.clientDataJSON),
      "passkey[authenticator_data]": this.#bufferToBase64url(credential.response.authenticatorData),
      "passkey[signature]": this.#bufferToBase64url(credential.response.signature)
    }

    for (const [name, value] of Object.entries(fields)) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    }

    document.body.appendChild(form)
    form.submit()
  }

  #prepareOptions(options) {
    const prepared = {
      ...options,
      challenge: this.#base64urlToBuffer(options.challenge)
    }

    if (options.allowCredentials?.length) {
      prepared.allowCredentials = options.allowCredentials.map(cred => ({
        ...cred,
        id: this.#base64urlToBuffer(cred.id)
      }))
    } else {
      delete prepared.allowCredentials
    }

    return prepared
  }

  #base64urlToBuffer(base64url) {
    const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
    const padding = "=".repeat((4 - base64.length % 4) % 4)
    const binary = atob(base64 + padding)
    return Uint8Array.from(binary, c => c.charCodeAt(0)).buffer
  }

  #bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer)
    const binary = String.fromCharCode(...bytes)
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
  }
}
