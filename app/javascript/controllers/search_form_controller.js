import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput"]

  clearInput() {
    if (this.searchInputTarget.value) {
      this.searchInputTarget.value = ""
      this.searchInputTarget.focus()
    } else {
      this.dispatch("reset")
    }
  }
}
