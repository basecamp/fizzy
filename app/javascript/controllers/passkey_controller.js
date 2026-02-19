import { Controller } from "@hotwired/stimulus"
import { base64urlToBuffer, bufferToBase64url } from "helpers/base64url_helpers"

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
      "passkey[authenticator_data]": bufferToBase64url(credential.response.authenticatorData),
      "passkey[signature]": bufferToBase64url(credential.response.signature)
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
      challenge: base64urlToBuffer(options.challenge)
    }

    if (options.allowCredentials?.length) {
      prepared.allowCredentials = options.allowCredentials.map(cred => ({
        ...cred,
        id: base64urlToBuffer(cred.id)
      }))
    } else {
      delete prepared.allowCredentials
    }

    return prepared
  }
}
