import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { base64urlToBuffer, bufferToBase64url } from "helpers/base64url_helpers"

export default class extends Controller {
  static values = { publicKey: Object, registerUrl: String }
  static targets = ["button", "error", "cancelled"]

  async create() {
    this.buttonTarget.disabled = true
    this.errorTarget.hidden = true
    this.cancelledTarget.hidden = true

    try {
      const publicKey = this.#prepareOptions(this.publicKeyValue)
      const credential = await navigator.credentials.create({ publicKey })
      await this.#registerCredential(credential)
    } catch (error) {
      if (error.name === "AbortError" || error.name === "NotAllowedError") {
        this.cancelledTarget.hidden = false
      } else {
        this.errorTarget.hidden = false
      }
      this.buttonTarget.disabled = false
    }
  }

  async #registerCredential(credential) {
    const response = await post(this.registerUrlValue, {
      body: JSON.stringify({
        passkey: {
          client_data_json: new TextDecoder().decode(credential.response.clientDataJSON),
          attestation_object: bufferToBase64url(credential.response.attestationObject),
          transports: credential.response.getTransports?.() || []
        }
      }),
      contentType: "application/json",
      responseKind: "json"
    })

    if (response.ok) {
      const { location } = await response.json
      Turbo.visit(location)
    } else {
      throw new Error("Registration failed")
    }
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
