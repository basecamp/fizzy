import { Controller } from "@hotwired/stimulus"
import { orient } from "helpers/orientation_helpers"
import { isTouchDevice } from "helpers/platform_helpers"

export default class extends Controller {
  static targets = [ "dialog", "focusMouse", "focusTouch" ]
  static values = {
    modal: { type: Boolean, default: false },
    sizing: { type: Boolean, default: true },
    autoOpen: { type: Boolean, default: false }
  }

  connect() {
    this.dialogTarget.setAttribute("aria-hidden", "true")
    if (this.autoOpenValue) this.open()
  }

  focusTouchTargetConnected() {
    this.#setupFocus()
  }

  open() {
    const modal = this.modalValue

    if (modal) {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.show()
      orient({ target: this.dialogTarget, anchor: this.element })
    }

    this.loadLazyFrames()
    this.dialogTarget.setAttribute("aria-hidden", "false")
    this.dispatch("show")
  }

  toggle() {
    if (this.dialogTarget.open) {
      this.close()
    } else {
      this.open()
    }
  }

  close() {
    this.dialogTarget.close()
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.dialogTarget.blur()
    orient({ target: this.dialogTarget, reset: true })
    this.dispatch("close")
  }

  closeOnClickOutside({ target }) {
    if (!this.element.contains(target)) this.close()
  }

  preventCloseOnMorphing(event) {
    if (event.detail?.attributeName === "open") {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  loadLazyFrames() {
    Array.from(this.dialogTarget.querySelectorAll("turbo-frame")).forEach(frame => { frame.loading = "eager" })
  }

  captureKey(event) {
    if (event.key !== "Escape") { event.stopPropagation() }
  }

  #setupFocus() {
    const touch = isTouchDevice()
    if (this.hasFocusMouseTarget) this.focusMouseTarget.autofocus = !touch
    if (this.hasFocusTouchTarget) this.focusTouchTarget.autofocus = touch
  }
}
