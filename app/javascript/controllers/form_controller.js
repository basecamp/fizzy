import { Controller } from "@hotwired/stimulus"
import { debounce, nextFrame } from "helpers/timing_helpers";

export default class extends Controller {
  static targets = [ "cancel", "submit" ]

  static values = {
    debounceTimeout: { type: Number, default: 300 }
  }

  initialize() {
    this.debouncedSubmit = debounce(this.debouncedSubmit.bind(this), this.debounceTimeoutValue)
  }

  submit() {
    this.element.requestSubmit()
  }

  debouncedSubmit(event) {
    this.submit(event)
  }

  submitToTopTarget(event) {
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
}
