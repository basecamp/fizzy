import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:submit-end", this.#handleSubmitEnd.bind(this), { once: true })
    this.submit()
  }

  submit() {
    this.#markAsBusy()
    this.#disableSubmit()
    this.element.requestSubmit()
  }

  #handleSubmitEnd(event) {
    if (event.detail.success) {
      this.element.remove()
    } else {
      this.#clearBusy()
      this.#enableSubmit()
    }
  }

  #markAsBusy() {
    this.element.setAttribute("aria-busy", "true")
  }

  #clearBusy() {
    this.element.setAttribute("aria-busy", "false")
  }

  #disableSubmit() {
    this.#submitElements().forEach(element => element.disabled = true)
  }

  #enableSubmit() {
    this.#submitElements().forEach(element => element.disabled = false)
  }

  #submitElements() {
    return this.element.querySelectorAll("input[type=submit],button")
  }
}
