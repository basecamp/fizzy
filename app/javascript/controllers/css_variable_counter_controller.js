import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item", "counter" ]
  static values = {
    propertyName: String,
    maxValue: { type: Number, default: 15 } // should match first geared pagination page size
  }

  initialize() {
    this.#updateCounter = debounce(this.#updateCounter.bind(this), 50)
  }

  connect() {
    if (this.itemTargets.length > 0) {
      this.#updateCounter()
    }
  }

  itemTargetConnected() {
    this.#updateCounter()
  }

  itemTargetDisconnected() {
    this.#updateCounter()
  }

  #updateCounter = () => {
    if (!this.hasCounterTarget) return

    const count = Math.min(this.itemTargets.length, this.maxValueValue)
    this.counterTarget.style.setProperty(this.propertyNameValue, count)
  }
}
