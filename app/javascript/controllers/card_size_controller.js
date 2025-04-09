import { Controller } from "@hotwired/stimulus"

const SIZES = [ "one", "two", "three", "four", "five" ]

export default class extends Controller {
  static targets = [ "bubble" ]

  connect() {
    this.resize()
  }

  resize() {
    const [ min, max ] = this.#getScoreRange()

    this.bubbleTargets.forEach(bubble => {
      const score = this.#currentBubbleScore(bubble)
      const idx = Math.round((score - min) / (max - min) * (SIZES.length - 1))

      bubble.style.setProperty("--bubble-size", `var(--bubble-size-${SIZES[idx]})`)
    })
  }

  #getScoreRange() {
    var min = 0, max = 1;

    this.bubbleTargets.forEach(bubble => {
      const score = this.#currentBubbleScore(bubble)

      min = Math.min(min, score)
      max = Math.max(max, score)
    })

    return [ min, max ]
  }

  #currentBubbleScore(el) {
    const score = el.dataset.activityScore
    const scoreAt = el.dataset.activityScoreAt
    const daysAgo = (Date.now() / 1000 - scoreAt) / (60 * 60 * 24)

    return score / (2**daysAgo)
  }
}
