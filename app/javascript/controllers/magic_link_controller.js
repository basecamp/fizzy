import { Controller } from "@hotwired/stimulus"
import { onNextEventLoopTick } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "input" ]

  submitOnEnter(event) {
    event.preventDefault()
    this.submit()
  }

  submitOnPaste() {
    onNextEventLoopTick(() => this.submit())
  }

  submit() {
    if (this.inputTarget.disabled) return
    this.element.submit()
    this.inputTarget.disabled = true
  }
}
