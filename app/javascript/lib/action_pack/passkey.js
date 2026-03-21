// JS companion for the ActionPack::Passkey Ruby helpers.
//
// Binds click handlers to passkey buttons and manages the WebAuthn ceremony
// lifecycle (challenge refresh, credential creation/authentication, form submission).
//
// Expected data attributes:
//   [data-passkey="create"]              — triggers the registration ceremony
//   [data-passkey="sign_in"]             — triggers the authentication ceremony
//   [data-passkey-mediation="conditional"] — on a <form>, enables autofill-assisted sign in
//   [data-passkey-errors]                — container whose data-passkey-error-state is set on failure
//   [data-passkey-error="error|cancelled"] — children shown/hidden via CSS based on error state
//   [data-passkey-field="..."]           — hidden fields populated before form submission
//
// Custom events (all bubble):
//   passkey:start   — ceremony begun
//   passkey:success — credential obtained, form about to submit
//   passkey:error   — ceremony failed; detail: { error, cancelled }
//
// Meta tags (rendered by the Ruby form helpers):
//   <meta name="passkey-creation-options"> — JSON WebAuthn creation options
//   <meta name="passkey-request-options">  — JSON WebAuthn request options
//   <meta name="passkey-challenge-url">    — endpoint to refresh the challenge nonce

import { register, authenticate } from "lib/action_pack/webauthn"

let listeners
let currentDocument

document.addEventListener("DOMContentLoaded", setup)
document.addEventListener("turbo:load", setup)
document.addEventListener("turbo:before-cache", teardown)

// Set error state on the nearest [data-passkey-errors] container.
// The app's CSS is responsible for showing/hiding children based on
// the data-passkey-error-state attribute ("error" or "cancelled").
document.addEventListener("passkey:error", ({ target, detail: { cancelled } }) => {
  const container = target.closest("[data-passkey-errors]")

  if (container) {
    container.dataset.passkeyErrorState = cancelled ? "cancelled" : "error"
  }
})

// Bind click handlers to passkey buttons and attempt conditional mediation.
// Guards against duplicate setup.
function setup() {
  if (currentDocument !== document.documentElement) {
    currentDocument = document.documentElement

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
}

// Reset transient DOM state and unbind event handlers to prevent leaks and duplicate handlers.
function teardown() {
  currentDocument = null
  listeners?.abort()

  for (const button of document.querySelectorAll('[data-passkey][disabled]')) {
    button.disabled = false
  }

  for (const container of document.querySelectorAll("[data-passkey-errors]")) {
    delete container.dataset.passkeyErrorState
  }
}

// Run the WebAuthn registration ceremony: refresh the challenge, prompt the
// browser to create a credential, fill the form's hidden fields, and submit.
async function createPasskey(button) {
  const form = button.closest("form")

  if (form) {
    button.disabled = true
    button.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

    try {
      if (!passkeysAvailable()) throw new Error("Passkeys are not supported by this browser")

      const creationOptions = getCreationOptions()
      if (!creationOptions) throw new Error("Missing passkey creation options")

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

function passkeysAvailable() {
  return !!window.PublicKeyCredential
}

// Read WebAuthn creation options from the <meta> tag rendered by
// +passkey_creation_options_meta_tag+. Returns undefined if the tag is missing.
function getCreationOptions() {
  return getOptions("passkey-creation-options")
}

// Parse and return the JSON content of a <meta> tag by name.
function getOptions(name) {
  const meta = document.querySelector(`meta[name="${name}"]`)

  if (meta) {
    return JSON.parse(meta.content)
  }
}

// POST to the challenge endpoint to get a fresh nonce, preventing replay attacks
// when the page has been open for a while before the user initiates the ceremony.
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

// Populate the registration form's hidden fields with the credential response.
// Clones the transports template input for each reported transport.
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

// Run the WebAuthn authentication ceremony: refresh the challenge, prompt the
// browser to sign with an existing credential, fill the form, and submit.
async function signInWithPasskey(button) {
  const form = button.closest("form")

  if (form) {
    button.disabled = true
    button.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

    try {
      if (!passkeysAvailable()) throw new Error("Passkeys are not supported by this browser")

      const requestOptions = getRequestOptions()
      if (!requestOptions) throw new Error("Missing passkey request options")

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

// Read WebAuthn request options from the <meta> tag rendered by
// +passkey_request_options_meta_tag+. Returns undefined if the tag is missing.
function getRequestOptions() {
  return getOptions("passkey-request-options")
}

// Populate the authentication form's hidden fields with the assertion response.
function fillSignInForm(form, passkey) {
  form.querySelector('[data-passkey-field="id"]').value = passkey.id
  form.querySelector('[data-passkey-field="client_data_json"]').value = passkey.client_data_json
  form.querySelector('[data-passkey-field="authenticator_data"]').value = passkey.authenticator_data
  form.querySelector('[data-passkey-field="signature"]').value = passkey.signature
}

// Start the conditional mediation (autofill) ceremony if the page opts in with
// a form[data-passkey-mediation="conditional"] and the browser supports it.
// Unlike the button-driven ceremonies, this runs automatically on page load.
async function attemptConditionalMediation() {
  if (await conditionalMediationAvailable()) {
    const form = document.querySelector('form[data-passkey-mediation="conditional"]')
    form.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

    const requestOptions = getRequestOptions()

    try {
      await refreshChallenge(requestOptions)

      const passkey = await authenticate(requestOptions, { mediation: "conditional" })

      form.dispatchEvent(new CustomEvent("passkey:success", { bubbles: true }))
      fillSignInForm(form, passkey)
      form.submit()
    } catch (error) {
      const cancelled = error.name === "AbortError" || error.name === "NotAllowedError"
      form.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, cancelled } }))
    }
  }
}

// Check all preconditions for conditional mediation: the page has opted in,
// request options are present, the browser supports passkeys, and the browser
// supports the conditional mediation UI (autofill).
async function conditionalMediationAvailable() {
  return isConditionalMediationFormPresent() &&
         getRequestOptions() &&
         passkeysAvailable() &&
         await window.PublicKeyCredential.isConditionalMediationAvailable?.()
}

function isConditionalMediationFormPresent() {
  return !!document.querySelector('form[data-passkey-mediation="conditional"]')
}
