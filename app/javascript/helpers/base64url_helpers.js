export function base64urlToBuffer(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
  const padding = "=".repeat((4 - base64.length % 4) % 4)
  const binary = atob(base64 + padding)
  return Uint8Array.from(binary, c => c.charCodeAt(0)).buffer
}

export function bufferToBase64url(buffer) {
  const bytes = new Uint8Array(buffer)
  const binary = String.fromCharCode(...bytes)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}
