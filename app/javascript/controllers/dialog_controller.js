import { Controller } from "@hotwired/stimulus"
import { orient } from "helpers/orientation_helpers"
import { limitHeightToViewport } from "helpers/sizing_helpers"

export default class extends Controller {
  static targets = [ "dialog" ]
  static values = {
    modal: { type: Boolean, default: false }
  }

  connect() {
    this.dialogTarget.setAttribute("aria-hidden", "true")
  }

  open() {
    const modal = this.modalValue

    if (modal) {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.show()
      orient(this.dialogTarget)
    }

    limitHeightToViewport(this.dialogTarget, true)

    this.#loadLazyFrames()
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
    orient(this.dialogTarget, false)
    limitHeightToViewport(this.dialogTarget, false)
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

  #loadLazyFrames() {
    Array.from(this.dialogTarget.querySelectorAll("turbo-frame")).forEach(frame => { frame.loading = "eager" })
  }
}
