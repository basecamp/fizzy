export async function register(options) {
  const publicKey = prepareCreationOptions(options)
  const credential = await navigator.credentials.create({ publicKey })

  return {
    client_data_json: new TextDecoder().decode(credential.response.clientDataJSON),
    attestation_object: bufferToBase64url(credential.response.attestationObject),
    transports: credential.response.getTransports?.() || []
  }
}

export async function authenticate(options, { signal, mediation } = {}) {
  const publicKey = prepareRequestOptions(options)
  const credential = await navigator.credentials.get({ publicKey, signal, mediation })

  return {
    id: credential.id,
    client_data_json: new TextDecoder().decode(credential.response.clientDataJSON),
    authenticator_data: bufferToBase64url(credential.response.authenticatorData),
    signature: bufferToBase64url(credential.response.signature)
  }
}

function prepareCreationOptions(options) {
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

function prepareRequestOptions(options) {
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

function base64urlToBuffer(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
  const padding = "=".repeat((4 - base64.length % 4) % 4)
  const binary = atob(base64 + padding)
  return Uint8Array.from(binary, c => c.charCodeAt(0)).buffer
}

function bufferToBase64url(buffer) {
  const bytes = new Uint8Array(buffer)
  const binary = String.fromCharCode(...bytes)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}
