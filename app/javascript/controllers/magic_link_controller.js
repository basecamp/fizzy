import { Controller } from "@hotwired/stimulus"
import { onNextEventLoopTick } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "input" ]

  submit() {
    onNextEventLoopTick(() => {
      if (!this.inputTarget.disabled) {
        this.element.submit()
        this.inputTarget.disabled = true
      }
    })
  }
}
