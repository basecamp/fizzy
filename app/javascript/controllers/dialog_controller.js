import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog" ]
  static values = {
    modal: { type: Boolean, default: false }
  }

  connect() {
    console.log("connect")
  }

  open() {
    const modal = this.modalValue

    if (modal) {
      console.log(modal)
      this.dialogTarget.showModal()
    } else {
      console.log("NOT FOUND")
      this.dialogTarget.show()
    }
  }

  toggle() {
    if (this.dialogTarget.open) {
      this.close()
    } else {
      this.open()
    }
  }

  close() {
    this.dialogTarget.close()
    this.dialogTarget.blur()
  }

  closeOnClickOutside({ target }) {
    if (!this.element.contains(target)) this.close()
  }
}
