import { Controller } from "@hotwired/stimulus"
import { normalizeFilteredText } from "helpers/text_helpers"

export default class extends Controller {
  static values = { keyword: String, audio: String, image: String }
  static targets = [ "icon" ]

  connect() {
    this.iconTarget.src = atob(this.imageValue)
  }

  reveal({ detail: { value } }) {
    const wasHidden = this.element.hidden
    const match = normalizeFilteredText(value) === normalizeFilteredText(atob(this.keywordValue))
    this.element.toggleAttribute("hidden", !match)

    if (match && wasHidden) {
      this.#navigableList?.reset()
    }
  }

  play(event) {
    event.preventDefault()
    const audio = new Audio(atob(this.audioValue))
    const flair = document.createElement("div")
    flair.className = "extras__flair"
    flair.textContent = "\u{1F918}"
    document.body.appendChild(flair)

    this.iconTarget.classList.add("spin")
    audio.addEventListener("ended", () => {
      this.iconTarget.classList.remove("spin")
      flair.remove()
    })
    audio.play()
  }

  get #navigableList() {
    const element = this.element.closest("[data-controller~='navigable-list']")
    if (element) {
      return this.application.getControllerForElementAndIdentifier(element, "navigable-list")
    }
  }
}
