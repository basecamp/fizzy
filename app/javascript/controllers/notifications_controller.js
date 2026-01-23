import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static classes = [ "enabled" ]
  static targets = [ "subscribeButton", "explainer" ]
  static values = { subscriptionsUrl: String }
  
  async connect() {
    if (!this.#allowed) return

    switch(Notification.permission) {
      case "default":
        this.#showButtonToSubscribe()
        break
      case "granted":
        const registration = await this.#getServiceWorkerRegistration()
        const subscription = await registration?.pushManager?.getSubscription()

        if (registration && subscription) {
          this.element.classList.add(this.enabledClass)
        } else {
          this.#showButtonToSubscribe()
        }
        break
    }
  }

  async attemptToSubscribe() {
    if (this.#allowed) {
      const registration = await this.#getServiceWorkerRegistration() || await this.#registerServiceWorker()

      switch(Notification.permission) {
        case "denied":  { break }
        case "granted": { this.#subscribe(registration); break }
        case "default": { this.#requestPermissionAndSubscribe(registration) }
      }
    }
  }

  async isEnabled() {
    if (this.#allowed) {
      const registration = await this.#getServiceWorkerRegistration()
      const existingSubscription = await registration?.pushManager?.getSubscription()

      return Notification.permission == "granted" && registration && existingSubscription
    }
  }

  get #allowed() {
    return navigator.serviceWorker && window.Notification
  }

  async #getServiceWorkerRegistration() {
    return navigator.serviceWorker.getRegistration("/service-worker.js", { scope: "/" })
  }

  async #registerServiceWorker() {
    await navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
    return navigator.serviceWorker.ready
  }

  async #subscribe(registration) {
    registration.pushManager
      .subscribe({ userVisibleOnly: true, applicationServerKey: this.#vapidPublicKey })
      .then(subscription => {
        this.#syncPushSubscription(subscription)
      })
  }

  async #syncPushSubscription(subscription) {
    const response = await post(this.subscriptionsUrlValue, { body: this.#extractJsonPayloadAsString(subscription), responseKind: "turbo-stream" })
    if (response.ok) {
      this.element.classList.add(this.enabledClass)
      this.subscribeButtonTarget.hidden = true
    } else {
      subscription.unsubscribe()
    }
  }

  #showButtonToSubscribe() {
    this.subscribeButtonTarget.hidden = false
    this.explainerTarget.hidden = true
  }

  async #requestPermissionAndSubscribe(registration) {
    const permission = await Notification.requestPermission()
    if (permission === "granted") this.#subscribe(registration)
  }

  get #vapidPublicKey() {
    const encodedVapidPublicKey = document.querySelector('meta[name="vapid-public-key"]').content
    return this.#urlBase64ToUint8Array(encodedVapidPublicKey)
  }

  #extractJsonPayloadAsString(subscription) {
    const { endpoint, keys: { p256dh, auth } } = subscription.toJSON()
    return JSON.stringify({ push_subscription: { endpoint, p256dh_key: p256dh, auth_key: auth } })
  }

  // VAPID public key comes encoded as base64 but service worker registration needs it as a Uint8Array
  #urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray
  }
}
