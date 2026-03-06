import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { register } from "lib/action_pack/webauthn"

export default class extends Controller {
  static values = { publicKey: Object, registerUrl: String }
  static targets = ["button", "error", "cancelled"]

  async create() {
    this.buttonTarget.disabled = true
    this.errorTarget.hidden = true
    this.cancelledTarget.hidden = true

    try {
      const passkey = await register(this.publicKeyValue)
      await this.#registerPasskey(passkey)
    } catch (error) {
      if (error.name === "AbortError" || error.name === "NotAllowedError") {
        this.cancelledTarget.hidden = false
      } else {
        this.errorTarget.hidden = false
      }
      this.buttonTarget.disabled = false
    }
  }

  async #registerPasskey(passkey) {
    const response = await post(this.registerUrlValue, {
      body: JSON.stringify({ passkey }),
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
}
