import { register } from "lib/action_pack/webauthn"

document.addEventListener("click", async (event) => {
  const button = event.target.closest('[data-passkey="create"]')
  if (!button) return

  const form = button.closest("form")
  if (!form) return

  button.disabled = true

  try {
    const meta = document.querySelector('meta[name="passkey-creation-options"]')
    const publicKey = JSON.parse(meta.content)
    const passkey = await register(publicKey)

    form.querySelector('[data-passkey-field="client_data_json"]').value = passkey.client_data_json
    form.querySelector('[data-passkey-field="attestation_object"]').value = passkey.attestation_object

    const template = form.querySelector('[data-passkey-field="transports"]')
    for (const transport of passkey.transports) {
      const input = template.cloneNode()
      input.value = transport
      template.before(input)
    }
    template.remove()

    form.submit()
  } catch (error) {
    button.disabled = false

    const cancelled = error.name === "AbortError" || error.name === "NotAllowedError"
    button.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, cancelled } }))
  }
})
