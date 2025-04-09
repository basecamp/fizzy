import { Controller } from "@hotwired/stimulus"

const BOTTOM_THRESHOLD = 0

export default class extends Controller {
  static targets = [ "menu" ]
  static classes = [ "orientationTop" ]

  close() {
    this.menuTarget.close()
    this.#orient()
  }

  open() {
    this.menuTarget.show()
    this.#orient()
  }

  toggle() {
    this.menuTarget.open ? this.close() : this.open()
  }

  closeOnClickOutside({ target }) {
    if (!this.element.contains(target)) this.close()
  }

  #orient() {
    this.element.classList.toggle(this.orientationTopClass, this.#distanceToBottom < BOTTOM_THRESHOLD)
    this.menuTarget.style.setProperty("--max-width", this.#maxWidth + "px")
  }

  get #distanceToBottom() {
    return window.innerHeight - this.#boundingClientRect.bottom
  }

  get #maxWidth() {
    return window.innerWidth - this.#boundingClientRect.left
  }

  get #boundingClientRect() {
    return this.menuTarget.getBoundingClientRect()
  }
}
