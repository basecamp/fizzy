import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "timer" ]
  static values = { timeLimit: Number }

  #interval
  #startedAt

  start() {
    this.stop()
    this.#startedAt = performance.now()
    this.#interval = setInterval(() => this.updateTimer(), 250)
  }

  stop() {
    clearInterval(this.#interval)
    this.#interval = null
  }

  disconnect() {
    this.stop()
  }

  updateTimer() {
    if (this.hasTimerTarget) {
      const seconds = Math.floor((performance.now() - this.#startedAt) / 1000)
      this.timerTarget.textContent = `Assigning… ${seconds}s of up to ${this.timeLimitValue}s`
    }
  }
}
