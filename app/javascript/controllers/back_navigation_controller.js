import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { fallbackDestination: String }

  connect() {
    if (history.state.turbo?.restorationIndex > 0) {
      this.element.href = "javascript:history.back()"
    } else {
      this.element.href = this.fallbackDestinationValue
    }
  }
}
