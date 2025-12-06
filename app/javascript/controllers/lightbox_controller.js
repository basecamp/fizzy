import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "caption", "image", "dialog", "zoomedImage" ]

  open(event) {
    this.dialogTarget.showModal()
    this.#set(event.target.closest("a"))
  }

  // Wait for the transition to finish before resetting the image
  handleTransitionEnd(event) {
    if (event.target === this.dialogTarget && !this.dialogTarget.open) {
      this.reset()
    }
  }

  reset() {
    this.zoomedImageTarget.src = ""
    this.captionTarget.innerText = ""
    this.dispatch('closed')
  }

  #set(target) {
    const imageSrc = target.href
    const caption = target.dataset.lightboxCaptionValue

    this.zoomedImageTarget.src = imageSrc

    if (caption) {
      this.captionTarget.innerText = caption
    }
  }
}
