import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { limit: Number, count: Number }
  static targets = ["unassigned", "limitMessage"]

  connect() {
    this.updateState()
  }

  countValueChanged() {
    this.updateState()
  }

  updateState() {
    const atLimit = this.countValue >= this.limitValue

    this.unassignedTargets.forEach(el => {
      el.hidden = atLimit
    })

    if (this.hasLimitMessageTarget) {
      this.limitMessageTarget.hidden = !atLimit
    }
  }
}
