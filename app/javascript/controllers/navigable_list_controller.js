import { Controller } from "@hotwired/stimulus"
import { nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item", "input" ]
  static values = {
    reverseOrder: { type: Boolean, default: false },
    selectionAttribute: { type: String, default: "aria-selected" },
    focusOnSelection: { type: Boolean, default: true },
    actionableItems: { type: Boolean, default: false },
    reverseNavigation: { type: Boolean, default: false },
    leftRightNavigation: { type: Boolean, default: true },
  }

  connect() {
    this._onActivate = this.activate.bind(this)
    this._onDeactivate = this.deactivate.bind(this)

    this.element.addEventListener("navigable-list:activate", this._onActivate)
    this.element.addEventListener("navigable-list:deactivate", this._onDeactivate)

    // If the list is not inside a collapsible column, make it active by default
    const insideColumn = !!this.element.closest('[data-collapsible-columns-target="column"]')
    this.active = !insideColumn

    if (this.active) {
      this.reset()
    }
  }

  disconnect() {
    this.element.removeEventListener("navigable-list:activate", this._onActivate)
    this.element.removeEventListener("navigable-list:deactivate", this._onDeactivate)
  }

  // Actions

  activate() {
    if (this.active) return
    this.active = true

    this.reset()
  }

  deactivate() {
    if (!this.active) return
    this.active = false

    this.#clearSelection()
    if (this.hasInputTarget) this.inputTarget.removeAttribute("aria-activedescendant")
    if (this.currentItem && typeof this.currentItem.blur === "function") {
      try { this.currentItem.blur() } catch (e) {}
    }
    this.currentItem = null
  }

  reset(event) {
    if (!this.active) return

    this.reverseOrderValue ? this.selectLast() : this.selectFirst()
  }

  navigate(event) {
    if (!this.active) return

    this.#keyHandlers[event.key]?.call(this, event)
  }

  select({ target }) {
    this.#setCurrentFrom(target)
  }

  selectCurrentOrReset(event) {
    if (this.currentItem) {
      this.#setCurrentFrom(this.currentItem)
    } else {
      this.reset()
    }
  }

  selectFirst() {
    this.#setCurrentFrom(this.#visibleItems[0])
  }

  selectLast() {
    this.#setCurrentFrom(this.#visibleItems[this.#visibleItems.length - 1])
  }

  // Private

  get #visibleItems() {
    return this.itemTargets.filter(item => {
      return item.checkVisibility() && !item.hidden
    })
  }

  #selectPrevious() {
    const index = this.#visibleItems.indexOf(this.currentItem)
    if (index > 0) {
      this.#setCurrentFrom(this.#visibleItems[index - 1])
    }
  }

  #selectNext() {
    const index = this.#visibleItems.indexOf(this.currentItem)
    if (index >= 0 && index < this.#visibleItems.length - 1) {
      this.#setCurrentFrom(this.#visibleItems[index + 1])
    }
  }

  async #setCurrentFrom(element) {
    const selectedItem = this.#visibleItems.find(item => item.contains(element))
    const id = selectedItem?.getAttribute("id")

    if (selectedItem) {
      this.#clearSelection()
      selectedItem.setAttribute(this.selectionAttributeValue, "true")
      this.currentItem = selectedItem
      await nextFrame()
      try {
        this.currentItem.scrollIntoView({ block: "nearest", inline: "nearest" })
      } catch (e) {}

      if (this.focusOnSelectionValue) { this.currentItem.focus() }
      if (this.hasInputTarget && id) {
        this.inputTarget.setAttribute("aria-activedescendant", id)
      }
    }
  }

  #clearSelection() {
    for (const item of this.itemTargets) {
      item.removeAttribute(this.selectionAttributeValue)
    }
  }

  #handleArrowKey(event, fn, preventDefault = true) {
    if (event.shiftKey || event.metaKey || event.ctrlKey) { return }
    fn.call()
    if (preventDefault) { event.preventDefault() }
  }

  #clickCurrentItem(event) {
    if (this.actionableItemsValue && this.currentItem && this.#visibleItems.length) {
      const clickableElement = this.currentItem.querySelector("a,button") || this.currentItem
      clickableElement.click()
      event.preventDefault()
    }
  }

  #toggleCurrentItem(event) {
    if (this.actionableItemsValue && this.currentItem && this.#visibleItems.length) {
      const toggleable = this.currentItem.querySelector("input[type=checkbox]")
      const isDisabled = toggleable.hasAttribute("disabled")

      if (toggleable) {
        if (!isDisabled) {
          toggleable.checked = !toggleable.checked
          toggleable.dispatchEvent(new Event('change', { bubbles: true }))
        }
        event.preventDefault()
      }
    }
  }

  #keyHandlers = {
    ArrowDown(event) {
      const selectMethod = this.reverseNavigationValue ? this.#selectPrevious.bind(this) : this.#selectNext.bind(this)
      this.#handleArrowKey(event, selectMethod)
    },
    ArrowUp(event) {
      const selectMethod = this.reverseNavigationValue ? this.#selectNext.bind(this) : this.#selectPrevious.bind(this)
      this.#handleArrowKey(event, selectMethod)
    },
    ArrowRight(event) {
      if (this.leftRightNavigationValue) {
        this.#handleArrowKey(event, this.#selectNext.bind(this), false)
      }
    },
    ArrowLeft(event) {
      if (this.leftRightNavigationValue) {
        this.#handleArrowKey(event, this.#selectPrevious.bind(this), false)
      }
    },
    Enter(event) {
      if (event.shiftKey) {
        this.#toggleCurrentItem(event)
      } else {
        this.#clickCurrentItem(event)
      }
    },
  }
}
