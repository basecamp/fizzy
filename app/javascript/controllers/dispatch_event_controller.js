import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { name: String }

  fire() {
    this.dispatch(this.nameValue, { target: document, prefix: false })
  }
}
