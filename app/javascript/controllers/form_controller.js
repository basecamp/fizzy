import { Controller } from "@hotwired/stimulus"
import { debounce, nextFrame } from "helpers/timing_helpers";

export default class extends Controller {
  static targets = [ "cancel", "submit", "input" ]

  static values = {
    debounceTimeout: { type: Number, default: 300 }
  }

  #isComposing = false

  initialize() {
    this.debouncedSubmit = debounce(this.debouncedSubmit.bind(this), this.debounceTimeoutValue)
  }

  // IME Composition tracking
  compositionStart() {
    this.#isComposing = true
  }

  compositionEnd() {
    this.#isComposing = false
  }

  submit() {
    this.element.requestSubmit()
  }

  preventEmptySubmit(event) {
    const input = this.hasInputTarget ? this.inputTarget : null

    if (input) {
      const value = (input.value || "").trim()
      const isEmpty = value.length === 0

      if (isEmpty) {
        event.preventDefault()
        input.setCustomValidity(input.dataset.validationMessage || "Please fill out this field")
        input.reportValidity()
        input.addEventListener("input", () => input.setCustomValidity(""), { once: true })
      }
    }
  }

  preventComposingSubmit(event) {
    if (this.#isComposing) {
      event.preventDefault()
    }
  }

  debouncedSubmit(event) {
    this.submit(event)
  }

  submitToTopTarget(event) {
    const value = event.target.value?.trim()

    if (!value) return false

    this.element.setAttribute("data-turbo-frame", "_top")
    this.submit()
  }

  reset() {
    this.element.reset()
  }

  cancel() {
    this.cancelTarget?.click()
  }

  preventAttachment(event) {
    event.preventDefault()
  }

  async disableSubmitWhenInvalid(event) {
    await nextFrame()

    if (this.element.checkValidity()) {
      this.submitTarget.removeAttribute("disabled")
    } else {
      this.submitTarget.toggleAttribute("disabled", true)
    }
  }

  select(event) {
    event.target.select()
  }

  blurActiveInput() {
    document.activeElement?.blur()
  }
}
