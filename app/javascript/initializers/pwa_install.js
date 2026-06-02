window.addEventListener("beforeinstallprompt", (e) => {
  const ua = navigator.userAgent
  if (!(/Android/i.test(ua) && /Chrome/i.test(ua))) return;

  e.preventDefault()

  window.deferredPrompt = e
  window.dispatchEvent(new CustomEvent("pwa-install:available"))
})
