import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "timer", "statusLine" ]
  static values = {
    candidateCount: { type: Number, default: 0 },
    userCount: { type: Number, default: 0 },
    timeLimit: { type: Number, default: 0 }
  }

  #interval = null
  #start = null

  start() {
    this.stop()
    this.#start = performance.now()
    this.timerTarget.textContent = "Planning… 0s"
    this.interval = setInterval(() => this.updateTimer(), 250)
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }

    if (this.#start) {
      const elapsed = Math.max(0, Math.round((performance.now() - this.#start) / 1000))
      const elapsedText = this.formatElapsed(elapsed)
      const message = this.statusLineTarget?.textContent || `Planning ${this.candidateCountValue} cards across ${this.userCountValue} people…`
      this.timerTarget.textContent = `${message} in ${elapsedText}`
    } else {
      this.timerTarget.textContent = "Planning complete"
    }
  }

  updateTimer() {
    const elapsed = Math.max(0, Math.floor((performance.now() - this.#start) / 1000))
    const elapsedText = this.formatElapsed(elapsed)
    this.timerTarget.textContent = `Elapsed ${elapsedText} of up to ${this.timeLimitValue}s`
  }

  formatElapsed(seconds) {
    return `${seconds}s`
  }

  get interval() {
    return this.#interval
  }

  set interval(value) {
    this.#interval = value
  }
}
