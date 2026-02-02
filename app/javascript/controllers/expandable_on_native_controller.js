import { Controller } from "@hotwired/stimulus"
import { isNative } from "helpers/platform_helpers"

export default class extends Controller {
  static get shouldLoad() {
    return isNative()
  }

  static values = { autoExpandSelector: String }

  connect() {
    if (this.hasAutoExpandSelectorValue && this.element.querySelector(this.autoExpandSelectorValue)) {
      this.element.open = true
    }
  }
}
