import { Controller } from "@hotwired/stimulus"
import { base64urlToBuffer, bufferToBase64url } from "helpers/base64url_helpers"

export default class extends Controller {
  static values = { publicKey: Object }
  static targets = ["clientDataJSON", "attestationObject"]

  async create(event) {
    try {
      const publicKey = this.#prepareOptions(this.publicKeyValue)
      const credential = await navigator.credentials.create({ publicKey })
      this.#submitCredential(credential)
    } catch (error) {
      if (error.name !== "AbortError" && error.name !== "NotAllowedError") {
        console.error("Registration failed:", error)
      }
    }
  }

  #submitCredential(credential) {
    this.clientDataJSONTarget.value = new TextDecoder().decode(credential.response.clientDataJSON)
    this.attestationObjectTarget.value = bufferToBase64url(credential.response.attestationObject)

    for (const transport of credential.response.getTransports?.() || []) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "passkey[transports][]"
      input.value = transport
      this.element.appendChild(input)
    }

    this.element.requestSubmit()
  }

  #prepareOptions(options) {
    return {
      ...options,
      challenge: base64urlToBuffer(options.challenge),
      user: { ...options.user, id: base64urlToBuffer(options.user.id) },
      excludeCredentials: (options.excludeCredentials || []).map(cred => ({
        ...cred,
        id: base64urlToBuffer(cred.id)
      }))
    }
  }
}
