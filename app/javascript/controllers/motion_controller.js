import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["autoButton", "reduceButton", "animateButton"]

  connect() {
    this.#updateButtons()
  }

  setAuto() {
    this.#motion = "auto"
  }

  setReduce() {
    this.#motion = "reduce"
  }

  setAnimate() {
    this.#motion = "animate"
  }

  get #storedMotion() {
    return localStorage.getItem("motion") || "auto"
  }

  set #motion(motion) {
    localStorage.setItem("motion", motion)

    if (motion === "reduce") {
      document.documentElement.dataset.motion = "reduce"
      this.#removeViewTransitionMeta()
    } else if (motion === "animate") {
      document.documentElement.dataset.motion = "animate"
      this.#restoreViewTransitionMeta()
    } else {
      delete document.documentElement.dataset.motion  // absent → patch falls through to OS
      const reduced = this.#osPreferReducedMotion
      document.documentElement.dataset.motion = reduced ? "reduce" : "animate"
      reduced ? this.#removeViewTransitionMeta() : this.#restoreViewTransitionMeta()
    }

    this.#updateButtons()
  }

  get #osPreferReducedMotion() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
  }

  #removeViewTransitionMeta() {
    document.querySelector('meta[name="view-transition"]')?.remove()
  }

  #restoreViewTransitionMeta() {
    if (!document.querySelector('meta[name="view-transition"]')) {
      const meta = document.createElement("meta")
      meta.name = "view-transition"
      meta.content = "same-origin"
      document.head.appendChild(meta)
    }
  }

  #updateButtons() {
    const stored = this.#storedMotion

    if (this.hasAutoButtonTarget)    { this.autoButtonTarget.checked   = (stored === "auto") }
    if (this.hasReduceButtonTarget)  { this.reduceButtonTarget.checked  = (stored === "reduce") }
    if (this.hasAnimateButtonTarget) { this.animateButtonTarget.checked = (stored === "animate") }
  }
}
