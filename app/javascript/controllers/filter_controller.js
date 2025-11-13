import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers"
import { filterMatches } from "helpers/text_helpers"

export default class extends Controller {
  static targets = [ "input", "item" ]

  initialize() {
    this.filter = debounce(this.filter.bind(this), 100)
  }

  filter() {
    this.itemTargets.forEach(item => {
      if (filterMatches(item.textContent, this.inputTarget.value)) {
        item.removeAttribute("hidden")
      } else {
        item.toggleAttribute("hidden", true)
      }
    })

    this.dispatch("changed")
  }

  clearInput() {
    if (!this.hasInputTarget) return
    this.inputTarget.value = ""
  }
}
