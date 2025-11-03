import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static targets = [ "turboFrame", "search", "searchInput", "form", "buttonsContainer" ]
  static outlets = [ "dialog" ]
  static values = {
    searchUrl: String,
  }

  dialogOutletConnected(outlet, element) {
    outlet.close()
    this.#clearTurboFrame()
  }

  reset() {
    this.dialogOutlet.close()
    this.#clearTurboFrame()

    this.#showItem(this.buttonsContainerTarget)
    this.#hideItem(this.searchTarget)
  }

  showModalAndSubmit(event) {
    this.showModal()
    this.formTarget.requestSubmit()
  }

  showModal() {
    this.dialogOutlet.open()
  }

  search(event) {
    this.#showItem(this.searchTarget)
    this.#hideItem(this.buttonsContainerTarget)

    if (this.searchInputTarget.value.trim()) {
      this.showModalAndSubmit()
    } else {
      this.#loadTurboFrame()
    }
  }

  #loadTurboFrame() {
    this.turboFrameTarget.src = this.searchUrlValue
  }

  #clearTurboFrame() {
    this.turboFrameTarget.removeAttribute("src")
    this.turboFrameTarget.innerHtml = ""
  }

  #showItem(element) {
    element.removeAttribute("hidden")

    const autofocusElement = element.querySelector("[autofocus]")
    autofocusElement?.focus()
    autofocusElement?.select()
  }

  #hideItem(element) {
    element.setAttribute("hidden", "hidden")
  }
}
