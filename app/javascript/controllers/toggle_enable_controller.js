import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "element", "checkbox" ]

  toggle() {
    this.elementTargets.forEach((element) => {
      element.toggleAttribute("disabled")
    })
  }

  reset() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    this.elementTargets.forEach((element) => {
      element.toggleAttribute("disabled", true)
    })
  }
}
