import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  morphRender({ detail }) {
    detail.render = function (currentElement, newElement) {
      Turbo.morphChildren(currentElement, newElement)
    }
  }

  morphReload(event) {
    const newElement = event.detail.newElement
    if (newElement && newElement.tagName === "TURBO-FRAME" && newElement.matches('[data-controller~="frame"]')) {
      event.preventDefault()
      this.#reloadFrom(newElement.getAttribute("src"))
    }
  }

  reload() {
    this.element.reload()
  }

  // Follow the server when it hands the frame a different src, as when a
  // filtered board refreshes a column that a stream rendered unfiltered.
  #reloadFrom(src) {
    if (src && src !== this.element.getAttribute("src")) {
      this.element.src = src
    } else {
      this.element.reload()
    }
  }
}
