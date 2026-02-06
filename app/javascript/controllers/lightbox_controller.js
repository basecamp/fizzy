import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "caption", "image", "dialog", "zoomedImage" ]

  imageTargetConnected(element) {
    element.addEventListener("click", this.#handleImageClick)
  }

  imageTargetDisconnected(element) {
    element.removeEventListener("click", this.#handleImageClick)
  }

  #handleImageClick = (event) => {
    event.preventDefault()
    this.#open(event.currentTarget)
  }

  #open(link) {
    this.dialogTarget.showModal()
    this.#set(link)
  }

  // Wait for the transition to finish before resetting the image
  handleTransitionEnd(event) {
    if (event.target === this.dialogTarget && !this.dialogTarget.open) {
      this.reset()
    }
  }

  reset() {
    this.zoomedImageTarget.src = ""
    this.captionTarget.innerHTML = "&nbsp;"
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
