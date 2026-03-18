import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { "target": String }

  forSelectedOption(event) {
    const text = this.element.selectedOptions[0]?.dataset.text
    const target = document.querySelector(this.targetValue)
    if (text && target) {
      target.textContent = text
    }
  }
}
