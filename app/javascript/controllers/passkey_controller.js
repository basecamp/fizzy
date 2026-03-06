import { Controller } from "@hotwired/stimulus"
import { authenticate } from "lib/action_pack/webauthn"

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
    if (!await window.PublicKeyCredential?.isConditionalMediationAvailable?.()) return

    this.#abortController = new AbortController()

    try {
      const passkey = await authenticate(this.publicKeyValue, {
        signal: this.#abortController.signal,
        mediation: "conditional"
      })

      this.#submitPasskey(passkey)
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Passkey error:", error)
      }
    }
  }

  #submitPasskey(passkey) {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.urlValue
    form.style.display = "none"

    const fields = {
      authenticity_token: this.csrfTokenValue,
      "passkey[id]": passkey.id,
      "passkey[client_data_json]": passkey.client_data_json,
      "passkey[authenticator_data]": passkey.authenticator_data,
      "passkey[signature]": passkey.signature
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
}
