import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async clearCache() {
    const registration = await navigator.serviceWorker?.ready
    registration?.active?.postMessage({ action: "clearCache" })
  }
}
