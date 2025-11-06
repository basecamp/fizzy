import { Controller } from "@hotwired/stimulus"
import { nextEventLoopTick } from "helpers/timing_helpers";

export default class extends Controller {
  static targets = ["meCheckbox"]
  static values = { selfRemovalPromptMessage: { type: String, default: "Are you sure?" } }

  async submitWithWarning(event) {
    if (this.hasMeCheckboxTarget && !this.meCheckboxTarget.checked && !this.confirmed) {
      event.detail.formSubmission.stop()

      const message = this.selfRemovalPromptMessageValue

      if (confirm(message)) {
        await nextEventLoopTick()
        this.confirmed = true
        this.element.requestSubmit()
      }
    }
  }
}
