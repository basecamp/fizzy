import { Controller } from "@hotwired/stimulus"
import { nextFrame } from "helpers/timing_helpers";

export default class extends Controller {
  static targets = [ "clickable" ]
  static outlets = [ "auto-save" ]

  async click() {
    if (this.hasAutoSaveOutlet) {
      await this.autoSaveOutlet.submit()
    }
    await nextFrame()
    this.#clickable.click()
  }

  get #clickable() {
    return this.hasClickableTarget ? this.clickableTarget : this.element
  }
}
