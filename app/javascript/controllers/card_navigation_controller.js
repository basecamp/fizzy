import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

export default class extends Controller {
  static targets = [ "previous", "next" ]
  static values = { url: String, number: Number, board: String, path: String }

  async connect() {
    this.navigating = false
    this.snapshot = this.#readSnapshot()

    try {
      await this.#refresh()
    } catch {
      // Keep the card usable when navigation cannot be loaded (including offline).
      this.#disableButtons()
    }
  }

  previous(event) {
    this.#navigate(event, -1)
  }

  next(event) {
    this.#navigate(event, 1)
  }

  leaving({ detail: { url } }) {
    if (url !== this.destination) {
      try { sessionStorage.removeItem(this.#storageKey) } catch { }
    }
  }

  async #refresh() {
    const url = new URL(this.urlValue, location.origin)
    if (this.snapshot) { url.searchParams.set("column_id", this.snapshot.columnId) }

    const response = await get(url, { responseKind: "json" })
    if (!response.ok) { throw new Error("Navigation unavailable") }

    const { numbers, column_id, name } = await response.json
    if (!this.element.isConnected) { throw new Error("Navigation disconnected") }
    this.availableNumbers = new Set(numbers)
    this.snapshot ||= {
      numbers, columnId: column_id, board: this.boardValue,
      current: this.numberValue, returnUrl: this.#returnUrl,
      returnLabel: this.#backLink.querySelector("strong").textContent
    }
    this.#saveSnapshot()
    this.#updateButton(this.previousTarget, -1, name)
    this.#updateButton(this.nextTarget, 1, name)

    // Run after turbo-navigation restores its one-hop referrer so Esc still returns to the board.
    requestAnimationFrame(() => {
      if (this.element.isConnected) {
        const link = this.#backLink
        link.href = this.snapshot.returnUrl
        link.querySelector("strong").textContent = this.snapshot.returnLabel
      }
    })
  }

  #readSnapshot() {
    try {
      const snapshot = JSON.parse(sessionStorage.getItem(this.#storageKey))
      if (snapshot?.board === this.boardValue && snapshot.current === this.numberValue &&
          Array.isArray(snapshot.numbers) && snapshot.numbers.includes(this.numberValue)) {
        return snapshot
      }
    } catch { }
    return null
  }

  get #backLink() {
    return document.querySelector("#header a.btn--back")
  }

  get #storageKey() {
    return `card-navigation:${this.pathValue}`
  }

  get #returnUrl() {
    let referrer
    try { referrer = sessionStorage.getItem("referrerUrl") } catch { }
    if (referrer) {
      const url = new URL(referrer, location.origin)
      const accountPath = this.boardValue.split("/boards/")[0]
      const allowed = [ accountPath, `${accountPath}/`, `${accountPath}/cards`, this.boardValue ].includes(url.pathname) ||
                      url.pathname.startsWith(`${this.boardValue}/columns/`)
      if (url.origin === location.origin && allowed) {
        return url.href
      }
    }
    return new URL(this.boardValue, location.origin).href
  }

  #saveSnapshot() {
    try { sessionStorage.setItem(this.#storageKey, JSON.stringify(this.snapshot)) } catch { }
  }

  #neighbor(direction) {
    const index = this.snapshot.numbers.indexOf(this.numberValue)
    if (index < 0) { return null }

    for (let i = index + direction; i >= 0 && i < this.snapshot.numbers.length; i += direction) {
      const number = this.snapshot.numbers[i]
      if (this.availableNumbers.has(number)) { return number }
    }
    return null
  }

  #updateButton(button, direction, name) {
    button.disabled = this.#neighbor(direction) === null
    button.title = `${direction < 0 ? "Previous" : "Next"} card in ${name} (Shift + ${direction < 0 ? "↑" : "↓"})`
  }

  #disableButtons() {
    this.previousTarget.disabled = true
    this.nextTarget.disabled = true
  }

  async #navigate(event, direction) {
    if (event.defaultPrevented || event.isComposing || event.repeat || this.navigating || !this.snapshot ||
        document.querySelector("dialog[open], form[data-local-save-key-value^='card-']") ||
        (event.type === "keydown" && event.target.closest("input, textarea, select, [contenteditable], lexxy-editor"))) {
      return
    }

    event.preventDefault()
    this.navigating = true
    this.#disableButtons()

    try {
      // Revalidate membership before navigating: removed, moved and closed cards are skipped.
      await this.#refresh()
      const number = this.#neighbor(direction)
      if (number !== null) {
        this.snapshot.current = number
        this.#saveSnapshot()
        this.destination = new URL(this.pathValue.replace("__number__", number), location.origin).href
        Turbo.visit(this.destination)
      } else {
        this.navigating = false
      }
    } catch {
      this.navigating = false
      this.#disableButtons()
    }
  }
}
