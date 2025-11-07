import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("dialog:show", this.handleDialogShow.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("dialog:show", this.handleDialogShow.bind(this))
  }

  handleDialogShow(event) {
    this.#dialogControllers.forEach(dialogController => {
      if (dialogController !== event.target) {
        const dialog = dialogController.querySelector("dialog")
        dialog.removeAttribute("open")
      }
    })
  }

  get #dialogControllers() {
    return this.element.querySelectorAll('[data-controller~="dialog"]')
  }
}
