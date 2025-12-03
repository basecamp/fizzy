import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]

  insertEmoji(event) {
    const emojiChar = event.target.getAttribute("data-emoji")
    const value = this.inputTarget.value
    const newValue = `${value}${emojiChar}`

    if (this.inputTarget.maxLength > 0 && newValue.length <= this.inputTarget.maxLength) {
      this.inputTarget.value = newValue
    }

    this.inputTarget.focus()
  }
}
