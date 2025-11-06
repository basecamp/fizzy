import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "toggle" ]
  static targets = [ "checkbox" ]

  toggle() {
    this.element.classList.toggle(this.toggleClass)
  }

  add() {
    this.element.classList.add(this.toggleClass)
  }

  remove() {
    this.element.classList.remove(this.toggleClass)
  }

  checkAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })
  }

  checkNone() {
    this.checkboxTargets.forEach(checkbox => {
      if (checkbox.dataset.boardsFormTarget === "meCheckbox") return
      checkbox.checked = false
    })
  }
}
