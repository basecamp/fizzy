import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { label: String }
  static targets = [ "referrerBackLink" ]

  rememberLocation() {
    sessionStorage.setItem("referrerUrl", window.location.href)
    sessionStorage.setItem("referrerLabel", this.labelValue)
  }

  backIfSamePath(event) {
    if (event.ctrlKey || event.metaKey || event.shiftKey) { return }

    const link = event.target.closest("a")
    const targetUrl = new URL(link.href)

    if (this.#referrerPath && targetUrl.pathname === this.#referrerPath) {
      event.preventDefault()
      Turbo.visit(this.#referrerUrl)
    }
  }

  referrerBackLinkTargetConnected(link) {
    if (!this.#referrerUrl || !this.#referrerLabel) { return }

    const stripTrailingSlash = path => path.replace(/\/$/, "")
    const allowedPaths = (link.dataset.turboNavigationAllowedReferrerPaths || "").split(",").map(stripTrailingSlash)
    const referrerPath = stripTrailingSlash(new URL(this.#referrerUrl).pathname)
    if (!allowedPaths.includes(referrerPath)) { return }

    link.href = this.#referrerUrl
    const strong = link.querySelector("strong")
    if (strong) { strong.textContent = `Back to ${this.#referrerLabel}` }
  }

  get #referrerPath() {
    if (!this.#referrerUrl) return null
    return new URL(this.#referrerUrl).pathname
  }

  get #referrerUrl() {
    return sessionStorage.getItem("referrerUrl")
  }

  get #referrerLabel() {
    return sessionStorage.getItem("referrerLabel")
  }
}
