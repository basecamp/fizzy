import { Controller } from "@hotwired/stimulus"
import { orient } from "helpers/orientation_helpers"

export default class extends Controller {
  static targets = [ "tooltip" ]

  connect() {
    this.element.addEventListener("mouseenter", this.mouseEnter.bind(this))
    this.element.addEventListener("mouseout", this.mouseOut.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.mouseEnter.bind(this))
    this.element.removeEventListener("mouseout", this.mouseOut.bind(this))
  }

  mouseEnter(event) {
    orient({ target: this.#tooltipElement, anchor: this.element })
  }

  mouseOut(event) {
    orient({ target: this.#tooltipElement, reset: true })
  }

  get #tooltipElement() {
    return this.element.querySelector(".for-screen-reader")
  }

  get #tooltipText() {
    return this.#tooltipElement.innerText
  }
}
