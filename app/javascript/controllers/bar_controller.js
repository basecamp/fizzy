import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { nextFrame } from "helpers/timing_helpers";

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

  clearInput() {
    if (this.searchInputTarget.value) {
      this.searchInputTarget.value = ""
      this.searchInputTarget.focus()
    } else {
      this.reset()
    }
  }

  showModalAndSubmit(event) {
    this.showModal()
    this.formTarget.requestSubmit()
    this.#restoreFocusAfterTurboFrameLoads()
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

  #restoreFocusAfterTurboFrameLoads() {
    this.turboFrameTarget.addEventListener("turbo:frame-load", () => {
      this.searchInputTarget.focus()
    }, { once: true })
  }

  #loadTurboFrame() {
    this.turboFrameTarget.src = this.searchUrlValue
  }

  #clearTurboFrame() {
    this.turboFrameTarget.removeAttribute("src")
    this.turboFrameTarget.innerHtml = ""
  }

  async #showItem(element) {
    element.removeAttribute("hidden")

    const autofocusElement = element.querySelector("[autofocus]")

    autofocusElement?.focus()
    await nextFrame()
    autofocusElement?.select()
  }

  #hideItem(element) {
    element.setAttribute("hidden", "hidden")
  }
}
