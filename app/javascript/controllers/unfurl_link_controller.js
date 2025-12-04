import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js"
import Cookie from "models/cookie"

export default class extends Controller {
  static targets = [ "linkAccountsPrompt" ]
  static values = {
    url: String,
    setUpBasecampIntegrationUrl: String
  }

  static MAX_DISMISSAL_COUNT = 3
  static DISMISSAL_COUNTER_KEY = "basecamp_integration_dimissal_count"

  #accountLinkingDismissed

  unfurl(event) {
    this.#unfurlLink(event.detail.url, event.detail)
  }

  setUpBasecampIntegration() {
    this.#openPopup(this.setUpBasecampIntegrationUrlValue, { width: 400, height: 600 })
  }

  closePrompt(event) {
    this.linkAccountsPromptTarget.hidden = true

    if (event.params.intent === "dismiss") {
      this.#incrementDismissalCounter()
    }
  }

  async #unfurlLink(url, callbacks) {
    const { response } = await post(
      this.urlValue,
      {
        body: JSON.stringify({ url }),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json"
        }
      }
    )

    let metadata = null

    if (response.status !== 204) {
      metadata = await response.json()
    }

    if (metadata?.error) {
      this.#handleError(metadata)
    } else if (metadata) {
      this.#insertUnfurledLink(metadata, callbacks)
    }
  }

  #insertUnfurledLink(metadata, callbacks) {
    callbacks.replaceLinkWith(this.#renderUnfurledLinkHTML(metadata))
  }

  #renderUnfurledLinkHTML(metadata) {
    return `<a href="${metadata.canonical_url}">${metadata.title}</a>`
  }

  #handleError({ error, ...data }) {
    switch (error) {
      case "unfurler_requires_setup":
        if (this.#shouldShowUnfurlerSetupPrompt()) {
          this.#promptUnfurlerSetUp(data.config)
        }
        break;
      default:
        throw new Error(`Unknown API error: ${error}`)
        break;
    }
  }

  #promptUnfurlerSetUp() {
    this.linkAccountsPromptTarget.hidden = false
  }

  #openPopup(url, options, onClose) {
    const { width, height } = options
    const left = (window.screen.width - width) / 2
    const top = (window.screen.height - height) / 2

    window.open(
      url,
      "_blank",
      `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes,toolbar=no,menubar=no,location=no,status=no`
    )
  }

  #incrementDismissalCounter() {
    this.#cookie.increment(this.constructor.DISMISSAL_COUNTER_KEY)
    this.#accountLinkingDismissed = true
  }

  #shouldShowUnfurlerSetupPrompt() {
    const dismissalCount = this.#cookie.get(this.constructor.DISMISSAL_COUNTER_KEY) || 0
    return !this.#accountLinkingDismissed && (dismissalCount < this.constructor.MAX_DISMISSAL_COUNT)
  }

  get #cookie() {
    const name = `link-unfurler-setup-prompt`
    return Cookie.find(name) || new Cookie(name)
  }
}
