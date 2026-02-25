import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static outlets = [ "navigable-list" ]

  connect() {
    this.morphCompletePromise = null
    this.morphCompleteResolver = null
  }

  handleKeydown(event) {
    if (this.#shouldIgnore(event) || this.#hasModifier(event)) return

    const handler = this.#keyHandlers[event.key.toLowerCase()]
    if (handler) {
      handler.call(this, event)
    }
  }

  // Called when turbo:morph completes - resolves our waiting promise
  handleMorphComplete() {
    if (this.morphCompleteResolver) {
      this.morphCompleteResolver()
      this.morphCompleteResolver = null
      this.morphCompletePromise = null
    }
  }

  // Private

  #shouldIgnore(event) {
    const target = event.target
    return target.tagName === "INPUT" ||
           target.tagName === "TEXTAREA" ||
           target.isContentEditable ||
           target.closest("input, textarea, [contenteditable], lexxy-editor")
  }

  #hasModifier(event) {
    return event.metaKey || event.ctrlKey || event.altKey || event.shiftKey
  }

  get #selectedCard() {
    // Find the navigable-list that currently has focus
    const focusedList = this.navigableListOutlets.find(list => list.hasFocus)
    if (!focusedList) return null

    const currentItem = focusedList.currentItem
    if (currentItem?.classList.contains("card") && !this.#hotkeysDisabled(focusedList)) {
      return { card: currentItem, controller: focusedList }
    }
    return null
  }

  async #postponeCard(event) {
    const selection = this.#selectedCard
    if (!selection) return

    const url = selection.card.dataset.cardNotNowUrl
    if (url) {
      event.preventDefault()
      await this.#performCardAction(url, selection)
    }
  }

  async #closeCard(event) {
    const selection = this.#selectedCard
    if (!selection) return

    const url = selection.card.dataset.cardClosureUrl
    if (url) {
      event.preventDefault()
      await this.#performCardAction(url, selection)
    }
  }

  async #assignToMe(event) {
    const selection = this.#selectedCard
    if (!selection) return

    const url = selection.card.dataset.cardAssignToSelfUrl
    if (url) {
      event.preventDefault()
      await post(url, { responseKind: "turbo-stream" })
    }
  }

  async #performCardAction(url, selection) {
    const { controller } = selection
    const visibleItems = controller.visibleItems
    const currentIndex = visibleItems.indexOf(selection.card)
    const wasLastItem = currentIndex === visibleItems.length - 1

    // Set up promise to wait for morph completion
    this.morphCompletePromise = new Promise(resolve => {
      this.morphCompleteResolver = resolve
    })

    await post(url, { responseKind: "turbo-stream" })

    // Wait for Turbo Stream morph to complete
    await Promise.race([
      this.morphCompletePromise,
      new Promise(resolve => setTimeout(resolve, 200)) // Fallback timeout
    ])

    // Select the next card (or previous if it was the last)
    const newVisibleItems = controller.visibleItems
    if (newVisibleItems.length === 0) {
      controller.clearSelection()
      return
    }

    if (wasLastItem) {
      controller.selectLast()
    } else {
      const nextIndex = Math.min(currentIndex, newVisibleItems.length - 1)
      if (newVisibleItems[nextIndex]) {
        await controller.selectItem(newVisibleItems[nextIndex])
      }
    }
  }

  #hotkeysDisabled(navigableList) {
    return navigableList?.element.dataset.cardHotkeysDisabled === "true"
  }

  #keyHandlers = {
    "["(event) { this.#postponeCard(event) },
    "]"(event) { this.#closeCard(event) },
    m(event) { this.#assignToMe(event) }
  }
}
