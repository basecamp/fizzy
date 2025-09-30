import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  rememberLocation() {
    sessionStorage.setItem("referrerUrl", window.location.href)
  }

  backIfSamePath(event) {
    const link = event.target.closest("a")
    const targetUrl = new URL(link.href)

    if (this.#referrerPath && targetUrl.pathname === this.#referrerPath) {
      event.preventDefault()
      Turbo.visit(this.#referrerUrl)
    }
  }
  get #referrerPath() {
    if (!this.#referrerUrl) return null
    return new URL(this.#referrerUrl).pathname
  }

  get #referrerUrl() {
    return sessionStorage.getItem("referrerUrl")
  }
}
