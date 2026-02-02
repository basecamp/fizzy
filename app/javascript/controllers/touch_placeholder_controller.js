import { Controller } from "@hotwired/stimulus"
import { isTouchDevice } from "helpers/platform_helpers"

export default class extends Controller {
  static get shouldLoad() {
    return isTouchDevice()
  }

  static values = { placeholder: String }

  connect() {
    if (this.hasPlaceholderValue) {
      this.element.placeholder = this.placeholderValue
    }
  }
}
