window.addEventListener("beforeinstallprompt", (e) => {
  e.preventDefault()
  
  window.deferredPrompt = e
  
  window.dispatchEvent(new CustomEvent("pwa-install:available"))
})
