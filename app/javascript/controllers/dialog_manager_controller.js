import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundHandleDialogShow = this.handleDialogShow.bind(this)
    this.element.addEventListener("dialog:show", this.boundHandleDialogShow)
  }

  disconnect() {
    this.element.removeEventListener("dialog:show", this.boundHandleDialogShow)
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
