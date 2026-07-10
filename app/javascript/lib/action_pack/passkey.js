// Web components for the ActionPack::Passkey Ruby helpers.
//
// <rails-passkey-registration-button> — wraps a registration ceremony form
// <rails-passkey-sign-in-button>  — wraps an authentication ceremony form
//
// The Ruby form helpers render the component markup including the inner form,
// hidden fields, button, and error messages. The components handle the WebAuthn
// ceremony lifecycle (challenge refresh, credential creation/authentication,
// form submission) and error state toggling.
//
// Custom events (all bubble):
//   passkey:start   — ceremony begun
//   passkey:success — credential obtained, form about to submit
//   passkey:error   — ceremony failed; detail: { error, cancelled }
//
// Attributes (rendered by the Ruby form helpers):
//   options       — JSON WebAuthn options (creation or request, on both)
//   challenge-url — endpoint to refresh the challenge nonce (on both)
//   mediation     — WebAuthn mediation hint, e.g. "conditional" (on rails-passkey-sign-in-button)

import { register, authenticate } from "lib/action_pack/webauthn"

// Base class for passkey web components. Manages the shared ceremony lifecycle:
// challenge refresh, button state, error display, and event dispatch.
// Subclasses implement `perform()` to run the specific WebAuthn ceremony
// and `fillForm()` to populate hidden fields before submission.
class PasskeyButton extends HTMLElement {
  connectedCallback() {
    this.button.addEventListener("click", this.#perform)
  }

  disconnectedCallback() {
    this.abortConditionalMediation?.()
    this.button.removeEventListener("click", this.#perform)
    this.button.disabled = false
    this.#hideErrors()
  }

  get button() {
    return this.querySelector("[data-passkey]")
  }

  get form() {
    return this.querySelector("form")
  }

  get options() {
    return JSON.parse(this.getAttribute("options"))
  }

  get challengeUrl() {
    return this.getAttribute("challenge-url")
  }

  // Arrow function to preserve `this` binding for addEventListener/removeEventListener.
  #perform = async () => {
    await this.abortConditionalMediation?.()
    this.button.disabled = true
    this.#hideErrors()
    this.button.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

    try {
      const options = this.options

      if (!passkeysAvailable()) throw new Error("Passkeys are not supported by this browser")
      if (!options) throw new Error("Missing passkey options")

      await refreshChallenge(options, this.challengeUrl, this.purpose)
      const passkey = await this.perform(options)

      this.button.dispatchEvent(new CustomEvent("passkey:success", { bubbles: true }))
      this.fillForm(passkey)
      this.form.submit()
    } catch (error) {
      this.button.disabled = false
      this.#handleError(error)
    }
  }

  #handleError(error) {
    console.error("Passkey ceremony failed", error)
    const type = errorType(error)
    this.#showError(type)
    this.button.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, type } }))
  }

  #showError(type) {
    const el = this.querySelector(`[data-passkey-error="${type}"]`)
    if (el) el.hidden = false
  }

  #hideErrors() {
    for (const el of this.querySelectorAll("[data-passkey-error]")) el.hidden = true
  }
}

class PasskeyRegistrationButton extends PasskeyButton {
  get purpose() { return "registration" }

  async perform(options) {
    return await register(options)
  }

  fillForm(passkey) {
    fillRegistrationForm(this.form, passkey)
  }
}

class PasskeySignInButton extends PasskeyButton {
  #conditionalMediationController = null
  #conditionalMediationPromise = null

  get purpose() { return "authentication" }

  connectedCallback() {
    super.connectedCallback()
    if (this.mediation === "conditional") this.#attemptConditionalMediation()
  }

  get mediation() {
    return this.getAttribute("mediation")
  }

  async perform(options, { signal, mediation } = {}) {
    return await authenticate(options, { signal, mediation })
  }

  fillForm(passkey) {
    fillSignInForm(this.form, passkey)
  }

  async abortConditionalMediation() {
    if (this.#conditionalMediationController) {
      this.#conditionalMediationController.abort()
      await this.#conditionalMediationPromise
    }
  }

  async #attemptConditionalMediation() {
    if (await this.#conditionalMediationAvailable()) {
      const options = this.options

      this.form.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

      this.#conditionalMediationController = new AbortController()
      this.#conditionalMediationPromise = this.#runConditionalMediation(options)
    }
  }

  async #runConditionalMediation(options) {
    try {
      await refreshChallenge(options, this.challengeUrl, this.purpose)
      const passkey = await this.perform(options, { signal: this.#conditionalMediationController.signal, mediation: this.mediation })

      this.form.dispatchEvent(new CustomEvent("passkey:success", { bubbles: true }))
      this.fillForm(passkey)
      this.form.submit()
    } catch (error) {
      if (error.name === "AbortError") return

      console.error("Passkey conditional mediation failed", error)
      const type = errorType(error)
      this.button.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, type } }))
    } finally {
      this.#conditionalMediationController = null
      this.#conditionalMediationPromise = null
    }
  }

  async #conditionalMediationAvailable() {
    return this.options &&
           passkeysAvailable() &&
           await window.PublicKeyCredential.isConditionalMediationAvailable?.()
  }
}

customElements.define("rails-passkey-registration-button", PasskeyRegistrationButton)
customElements.define("rails-passkey-sign-in-button", PasskeySignInButton)

// -- Shared helpers ----------------------------------------------------------

function errorType(error) {
  switch (error.name) {
    case "AbortError":
    case "NotAllowedError": return "cancelled"
    case "InvalidStateError": return "duplicate"
    default: return "error"
  }
}

function passkeysAvailable() {
  return !!window.PublicKeyCredential
}

async function refreshChallenge(options, challengeUrl, purpose) {
  if (!challengeUrl) throw new Error("Missing passkey challenge URL")
  const token = document.querySelector('meta[name="csrf-token"]')?.content

  const body = new URLSearchParams()
  if (purpose) body.append("purpose", purpose)

  const response = await fetch(challengeUrl, {
    method: "POST",
    credentials: "same-origin",
    headers: {
      "X-CSRF-Token": token,
      "Accept": "application/json"
    },
    body
  })

  if (!response.ok) throw new Error("Failed to refresh challenge")

  const { challenge } = await response.json()
  options.challenge = challenge
}

function fillRegistrationForm(form, passkey) {
  form.querySelector('[data-passkey-field="client_data_json"]').value = passkey.client_data_json
  form.querySelector('[data-passkey-field="attestation_object"]').value = passkey.attestation_object

  const template = form.querySelector('[data-passkey-field="transports"]')
  for (const transport of passkey.transports) {
    const input = template.cloneNode()
    input.value = transport
    template.before(input)
  }
  template.remove()
}

function fillSignInForm(form, passkey) {
  form.querySelector('[data-passkey-field="id"]').value = passkey.id
  form.querySelector('[data-passkey-field="client_data_json"]').value = passkey.client_data_json
  form.querySelector('[data-passkey-field="authenticator_data"]').value = passkey.authenticator_data
  form.querySelector('[data-passkey-field="signature"]').value = passkey.signature
}
