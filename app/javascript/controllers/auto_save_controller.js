import { Controller } from "@hotwired/stimulus"
import { submitForm } from "helpers/form_helpers"

const AUTOSAVE_INTERVAL = 3000

export default class extends Controller {
  #timer
  #saving

  // Lifecycle

  disconnect() {
    this.submit()
  }

  // Actions

  async submit() {
    if (this.#dirty) {
      this.#save()
    }

    await this.#saving
  }

  change(event) {
    if (event.target.form === this.element && !this.#dirty) {
      this.#scheduleSave()
    }
  }

  // Private

  #scheduleSave() {
    this.#timer = setTimeout(() => this.#save(), AUTOSAVE_INTERVAL)
  }

  #save() {
    this.#resetTimer()
    this.#saving = submitForm(this.element)
  }

  #resetTimer() {
    clearTimeout(this.#timer)
    this.#timer = null
  }

  get #dirty() {
    return !!this.#timer
  }
}
