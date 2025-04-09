import { Controller } from "@hotwired/stimulus"

const SIZES = [ "one", "two", "three", "four", "five" ]

export default class extends Controller {
  static targets = [ "card" ]

  connect() {
    this.resize()
  }

  resize() {
    const [ min, max ] = this.#getScoreRange()

    this.cardTargets.forEach(card => {
      const score = this.#currentCardScore(card)
      const idx = Math.round((score - min) / (max - min) * (SIZES.length - 1))

      card.style.setProperty("--card-size", `var(--card-size-${SIZES[idx]})`)
    })
  }

  #getScoreRange() {
    var min = 0, max = 1;

    this.cardTargets.forEach(card => {
      const score = this.#currentCardScore(card)

      min = Math.min(min, score)
      max = Math.max(max, score)
    })

    return [ min, max ]
  }

  #currentCardScore(el) {
    const score = el.dataset.activityScore
    const scoreAt = el.dataset.activityScoreAt
    const daysAgo = (Date.now() / 1000 - scoreAt) / (60 * 60 * 24)

    return score / (2**daysAgo)
  }
}
