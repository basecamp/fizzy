import { Controller } from "@hotwired/stimulus"
import { nextEventNamed } from "helpers/timing_helpers"
import { isTouchDevice } from "helpers/platform_helpers"

export default class extends Controller {
  // Only load for touch devices
  static get shouldLoad() {
    return isTouchDevice()
  }

  // Use a fake input to trigger the soft keyboard on actions that load async content
  // See https://gist.github.com/cathyxz/73739c1bdea7d7011abb236541dc9aaa
  async open(event) {
    const fakeInput = this.#focusOnFakeInput()
    this.#removeOnFocusOut(fakeInput)
  }

  #focusOnFakeInput() {
    const fakeInput = document.createElement("input")

    fakeInput.setAttribute("type", "text")
    fakeInput.setAttribute("class", "input--invisible")

    this.element.appendChild(fakeInput)
    fakeInput.focus()

    return fakeInput
  }

  async #removeOnFocusOut(element) {
    await nextEventNamed("focusout", element)
    element.remove()
  }
}
