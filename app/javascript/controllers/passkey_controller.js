import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["credential", "email"]
  static values = { options: Object, emailSelector: String }

  async register(event) {
    event.preventDefault()

    // Copy email from external input if emailSelector is provided
    if (this.hasEmailTarget && this.emailSelectorValue) {
      const emailInput = document.querySelector(this.emailSelectorValue)
      if (emailInput) {
        this.emailTarget.value = emailInput.value
      }
    }

    try {
      const options = this.#prepareCreateOptions(this.optionsValue)
      const credential = await navigator.credentials.create({ publicKey: options })

      this.credentialTarget.value = JSON.stringify(this.#serializeCreate(credential))
      this.element.requestSubmit()
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Passkey registration failed:", error)
      }
    }
  }

  async authenticate(event) {
    event.preventDefault()

    try {
      const credential = await navigator.credentials.get({
        publicKey: this.#prepareGetOptions(this.optionsValue)
      })

      this.credentialTarget.value = JSON.stringify(this.#serializeGet(credential))
      this.element.requestSubmit()
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Passkey authentication failed:", error)
      }
    }
  }

  #prepareCreateOptions(options) {
    // Remove empty extensions object - some authenticators don't handle it well
    const { extensions, ...restOptions } = options
    const preparedOptions = {
      ...restOptions,
      challenge: this.#base64urlToBuffer(options.challenge),
      user: {
        ...options.user,
        id: this.#base64urlToBuffer(options.user.id)
      },
      excludeCredentials: (options.excludeCredentials || []).map(c => ({
        ...c,
        id: this.#base64urlToBuffer(c.id)
      }))
    }
    
    // Only include extensions if non-empty
    if (extensions && Object.keys(extensions).length > 0) {
      preparedOptions.extensions = extensions
    }
    
    return preparedOptions
  }

  #prepareGetOptions(options) {
    // Remove empty extensions object - some authenticators don't handle it well
    const { extensions, ...restOptions } = options
    const preparedOptions = {
      ...restOptions,
      challenge: this.#base64urlToBuffer(options.challenge),
      allowCredentials: (options.allowCredentials || []).map(c => ({
        ...c,
        id: this.#base64urlToBuffer(c.id)
      }))
    }
    
    // Only include extensions if non-empty
    if (extensions && Object.keys(extensions).length > 0) {
      preparedOptions.extensions = extensions
    }
    
    return preparedOptions
  }

  #serializeCreate(credential) {
    return {
      id: credential.id,
      rawId: this.#bufferToBase64url(credential.rawId),
      type: credential.type,
      clientExtensionResults: credential.getClientExtensionResults ? credential.getClientExtensionResults() : {},
      authenticatorAttachment: credential.authenticatorAttachment || null,
      response: {
        clientDataJSON: this.#bufferToBase64url(credential.response.clientDataJSON),
        attestationObject: this.#bufferToBase64url(credential.response.attestationObject),
        transports: credential.response.getTransports ? credential.response.getTransports() : []
      }
    }
  }

  #serializeGet(credential) {
    return {
      id: credential.id,
      rawId: this.#bufferToBase64url(credential.rawId),
      type: credential.type,
      clientExtensionResults: credential.getClientExtensionResults ? credential.getClientExtensionResults() : {},
      authenticatorAttachment: credential.authenticatorAttachment || null,
      response: {
        clientDataJSON: this.#bufferToBase64url(credential.response.clientDataJSON),
        authenticatorData: this.#bufferToBase64url(credential.response.authenticatorData),
        signature: this.#bufferToBase64url(credential.response.signature),
        userHandle: credential.response.userHandle
          ? this.#bufferToBase64url(credential.response.userHandle)
          : null
      }
    }
  }

  #base64urlToBuffer(base64url) {
    const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
    const padded = base64 + "=".repeat((4 - base64.length % 4) % 4)
    const binary = atob(padded)
    return Uint8Array.from(binary, c => c.charCodeAt(0)).buffer
  }

  #bufferToBase64url(buffer) {
    // Handle ArrayBuffer, Uint8Array, or already-encoded string
    if (typeof buffer === "string") {
      // Already a string, assume it's base64url encoded
      return buffer
    }
    
    const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer)
    const binary = String.fromCharCode(...bytes)
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "")
  }
}
