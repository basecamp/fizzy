import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { viewport } from "helpers/bridge/viewport_helpers"
import { nextFrame } from "helpers/timing_helpers"

export default class extends BridgeComponent {
  static component = "title"
  static targets = [ "header" ]
  static values = { title: String }

  async connect() {
    super.connect()
    await nextFrame()
    this.#startObserver()
    window.addEventListener("resize", this.#windowResized)
  }

  disconnect() {
    super.disconnect()
    this.#stopObserver()
    window.removeEventListener("resize", this.#windowResized)
  }

  notifyBridgeOfVisibilityChange(visible) {
    this.send("visibility", { title: this.#title, elementVisible: visible })
  }

  // Intersection Observer

  #startObserver() {
    if (!this.hasHeaderTarget) return

    this.observer = new IntersectionObserver(([ entry ]) =>
      this.notifyBridgeOfVisibilityChange(entry.isIntersecting),
      { rootMargin: `-${this.#topOffset}px 0px 0px 0px` }
    )

    this.observer.observe(this.headerTarget)
    this.previousTopOffset = this.#topOffset
  }

  #stopObserver() {
    this.observer?.disconnect()
  }

  #updateObserverIfNeeded() {
    if (this.#topOffset === this.previousTopOffset) return

    this.#stopObserver()
    this.#startObserver()
  }

  #windowResized = () => {
    this.#updateObserverIfNeeded()
  }

  get #title() {
    return this.titleValue ? this.titleValue : document.title
  }

  get #topOffset() {
    return viewport.top
  }
}
