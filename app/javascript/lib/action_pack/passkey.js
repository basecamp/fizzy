import { register, authenticate } from "lib/action_pack/webauthn"

let listeners

document.addEventListener("DOMContentLoaded", setup)
document.addEventListener("turbo:load", setup)

function setup() {
  listeners?.abort()
  listeners = new AbortController()

  for (const button of document.querySelectorAll('[data-passkey="create"]')) {
    button.addEventListener("click", () => createPasskey(button), { signal: listeners.signal })
  }

  for (const button of document.querySelectorAll('[data-passkey="sign_in"]')) {
    button.addEventListener("click", () => signInWithPasskey(button), { signal: listeners.signal })
  }

  attemptConditionalMediation()
}

// Toggle error/cancellation messages near the passkey button.
// Containers opt in with [data-passkey-errors]; children use
// [data-passkey-error="error"] and [data-passkey-error="cancelled"].
document.addEventListener("passkey:error", ({ target, detail: { cancelled } }) => {
  const container = target.closest("[data-passkey-errors]")

  if (container) {
    for (const el of container.querySelectorAll("[data-passkey-error]")) {
      el.hidden = el.dataset.passkeyError !== (cancelled ? "cancelled" : "error")
    }
  }
})

async function createPasskey(button) {
  const form = button.closest("form")

  if (form) {
    button.disabled = true
    button.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

    try {
      if (!passkeysAvailable()) throw new Error("Passkeys are not supported by this browser")

      const meta = document.querySelector('meta[name="passkey-creation-options"]')
      if (!meta) throw new Error("Missing passkey creation options")

      const creationOptions = JSON.parse(meta.content)
      await refreshChallenge(creationOptions)
      const passkey = await register(creationOptions)

      button.dispatchEvent(new CustomEvent("passkey:success", { bubbles: true }))
      fillCreateForm(form, passkey)
      form.submit()
    } catch (error) {
      button.disabled = false

      const cancelled = error.name === "AbortError" || error.name === "NotAllowedError"
      button.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, cancelled } }))
    }
  }
}

async function signInWithPasskey(button) {
  const form = button.closest("form")

  if (form) {
    button.disabled = true
    button.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

    try {
      if (!passkeysAvailable()) throw new Error("Passkeys are not supported by this browser")

      const meta = document.querySelector('meta[name="passkey-request-options"]')
      if (!meta) throw new Error("Missing passkey request options")

      const requestOptions = JSON.parse(meta.content)
      await refreshChallenge(requestOptions)
      const passkey = await authenticate(requestOptions)

      button.dispatchEvent(new CustomEvent("passkey:success", { bubbles: true }))
      fillSignInForm(form, passkey)
      form.submit()
    } catch (error) {
      button.disabled = false

      const cancelled = error.name === "AbortError" || error.name === "NotAllowedError"
      button.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, cancelled } }))
    }
  }
}

async function attemptConditionalMediation() {
  if (await conditionalMediationAvailable()) {
    const form = document.querySelector('form[data-passkey-mediation="conditional"]')
    const publicKey = JSON.parse(document.querySelector('meta[name="passkey-request-options"]').content)
    await refreshChallenge(publicKey)

    form.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

    try {
      const passkey = await authenticate(publicKey, { mediation: "conditional" })

      form.dispatchEvent(new CustomEvent("passkey:success", { bubbles: true }))
      fillSignInForm(form, passkey)
      form.submit()
    } catch (error) {
      const cancelled = error.name === "AbortError" || error.name === "NotAllowedError"
      form.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, cancelled } }))
    }
  }
}

async function conditionalMediationAvailable() {
  return passkeysAvailable() && await window.PublicKeyCredential.isConditionalMediationAvailable?.()
}

function passkeysAvailable() {
  return !!window.PublicKeyCredential
}

async function refreshChallenge(options) {
  const url = document.querySelector('meta[name="passkey-challenge-url"]')?.content
  if (!url) throw new Error("Missing passkey challenge URL")
  const token = document.querySelector('meta[name="csrf-token"]')?.content

  const response = await fetch(url, {
    method: "POST",
    credentials: "same-origin",
    headers: {
      "X-CSRF-Token": token,
      "Accept": "application/json"
    }
  })

  if (!response.ok) throw new Error("Failed to refresh challenge")

  const { challenge } = await response.json()
  options.challenge = challenge
}

function fillCreateForm(form, passkey) {
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
