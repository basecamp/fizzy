import { register, authenticate } from "lib/action_pack/webauthn"

// Create passkey (explicit button click)
document.addEventListener("click", async (event) => {
  const button = event.target.closest('[data-passkey="create"]')
  if (!button) return

  const form = button.closest("form")
  if (!form) return

  button.disabled = true
  button.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

  try {
    if (!window.PublicKeyCredential) throw new Error("Passkeys are not supported by this browser")

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
})

// Sign in with passkey (explicit button click)
document.addEventListener("click", async (event) => {
  const button = event.target.closest('[data-passkey="sign_in"]')
  if (!button) return

  const form = button.closest("form")
  if (!form) return

  button.disabled = true
  button.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

  try {
    if (!window.PublicKeyCredential) throw new Error("Passkeys are not supported by this browser")

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
})

// Sign in with passkey (conditional mediation / autofill UI)
document.addEventListener("DOMContentLoaded", async () => {
  const form = document.querySelector('form[data-passkey-mediation="conditional"]')
  if (!form) return
  if (!await window.PublicKeyCredential?.isConditionalMediationAvailable?.()) return

  const meta = document.querySelector('meta[name="passkey-request-options"]')
  if (!meta) return

  const publicKey = JSON.parse(meta.content)
  await refreshChallenge(publicKey)

  try {
    const passkey = await authenticate(publicKey, { mediation: "conditional" })

    fillSignInForm(form, passkey)
    form.submit()
  } catch (error) {
    if (error.name !== "AbortError") {
      console.error("Passkey error:", error)
    }
  }
})

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
