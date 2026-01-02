import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "target" ]

  connect() {
    this.#scrollTargetIntoView()
  }

  #scrollTargetIntoView() {
    if(this.hasTargetTarget) {
      this.element.scrollTo({
        top: this.targetTarget.offsetTop - this.element.offsetHeight / 2 + this.targetTarget.offsetHeight / 2,
        left: this.targetTarget.offsetLeft - this.element.offsetWidth / 2 + this.targetTarget.offsetWidth / 2,
        behavior: "instant"
      })
    }
  }
}
