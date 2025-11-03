import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]

  insertEmoji(event) {
    const emojiChar = event.target.getAttribute("data-emoji")
    const value = this.inputTarget.value
    this.inputTarget.value = `${value}${emojiChar}`
    this.inputTarget.focus()
  }
}
