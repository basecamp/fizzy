import { Controller } from "@hotwired/stimulus"
import { nextFrame, debounce } from "helpers/timing_helpers";

// TODO: When collapsing, move focus to nearest expanded column

export default class extends Controller {
  static classes = [ "collapsed", "noTransitions", "titleNotVisible" ]
  static targets = [ "column", "button", "title", "maybe" ]
  static values = {
    board: String
  }

  initialize() {
    this.restoreState = debounce(this.restoreState.bind(this), 10)
    // TODO: The default focused column is Maybe (index 1), but the most recently expanded column should save to localStorage
    this.currentColumnIndex = 1
    this.#focus(this.allColumns[this.currentColumnIndex])
  }

  async connect() {
    await this.#restoreColumnsDisablingTransitions()
    this.#setupIntersectionObserver()
  }

  disconnect() {
    if (this._intersectionObserver) {
      this._intersectionObserver.disconnect()
      this._intersectionObserver = null
    }
  }

  toggle({ target }) {
    const column = target.closest('[data-collapsible-columns-target="column"]')
    this.#toggleColumn(column)
  }

  preventToggle(event) {
    if (event.target.hasAttribute("data-collapsible-columns-target") && event.detail.attributeName === "class") {
      event.preventDefault()
    }
  }

  navigate(event) {
    this.#keyHandlers[event.key]?.call(this, event)
  }

  async restoreState(event) {
    await nextFrame()
    await this.#restoreColumnsDisablingTransitions()
  }

  async #restoreColumnsDisablingTransitions() {
    this.#disableTransitions()
    this.#restoreColumns()

    await nextFrame()
    this.#enableTransitions()
  }

  #disableTransitions() {
    this.element.classList.add(this.noTransitionsClass)
  }

  #enableTransitions() {
    this.element.classList.remove(this.noTransitionsClass)
  }

  #toggleColumn(column) {
    this.#collapseAllExcept(column)

    if (this.#isCollapsed(column)) {
      this.#expand(column)
    } else {
      this.#collapse(column)
    }
  }

  #collapseAllExcept(clickedColumn) {
    this.columnTargets.forEach(column => {
      if (column !== clickedColumn) {
        this.#collapse(column)
      }
    })
  }

  #isCollapsed(column) {
    return column.classList.contains(this.collapsedClass)
  }

  #collapse(column) {
    const key = this.#localStorageKeyFor(column)

    this.#buttonFor(column).setAttribute("aria-expanded", "false")
    column.classList.add(this.collapsedClass)
    localStorage.removeItem(key)
  }

  #expand(column) {
    const key = this.#localStorageKeyFor(column)

    this.#buttonFor(column).setAttribute("aria-expanded", "true")
    column.classList.remove(this.collapsedClass)
    localStorage.setItem(key, true)
    this.#focus(column)
  }

  #buttonFor(column) {
    return this.buttonTargets.find(button => column.contains(button))
  }

  #restoreColumns() {
    this.columnTargets.forEach(column => {
      this.#restoreColumn(column)
    })
  }

  #restoreColumn(column) {
    const key = this.#localStorageKeyFor(column)
    if (localStorage.getItem(key)) {
      this.#expand(column)
    }
  }

  #localStorageKeyFor(column) {
    return `expand-${this.boardValue}-${column.getAttribute("id")}`
  }

  #setupIntersectionObserver() {
    if (typeof IntersectionObserver === "undefined") return
    if (this._intersectionObserver) this._intersectionObserver.disconnect()

    this._intersectionObserver = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        const title = entry.target
        const column = title.closest(".cards")

        if (!column) return

        const offscreen = entry.intersectionRatio === 0
        column.classList.toggle(this.titleNotVisibleClass, offscreen)
      })
    }, { threshold: [0] })

    this.titleTargets.forEach(title => this._intersectionObserver.observe(title))
  }

  #keyHandlers = {
    ArrowRight(event) {
      this.#handleArrowKey(event, this.#selectNext.bind(this), false)
    },
    ArrowLeft(event) {
      this.#handleArrowKey(event, this.#selectPrevious.bind(this), false)
    }
  }

  #handleArrowKey(event, fn, preventDefault = true) {
    if (event.shiftKey || event.metaKey || event.ctrlKey) { return }
    fn.call()
    if (preventDefault) { event.preventDefault() }
  }

  #selectPrevious() {
    if (this.currentColumnIndex > 0) {
      this.currentColumnIndex -= 1
      this.#navigateToColumn(this.currentColumnIndex)
    }
  }

  #selectNext() {
    if (this.currentColumnIndex < this.allColumns.length - 1) {
      this.currentColumnIndex += 1
      this.#navigateToColumn(this.currentColumnIndex)
    }
  }

  #navigateToColumn(index) {
    const column = this.allColumns[index]

    if (this.#isCollapsed(column)) {
      this.#toggleColumn(column)
    }

    this.#focus(column)
  }

  #focus(column) {
    const navigableLists = Array.from(document.querySelectorAll('.card-columns [data-controller~="navigable-list"]'))

    navigableLists.forEach(list => {
      if (column.contains(list)) {
        list.dispatchEvent(new CustomEvent("navigable-list:activate", { bubbles: false }))
      } else {
        list.dispatchEvent(new CustomEvent("navigable-list:deactivate", { bubbles: false }))
      }
    })
  }

  get allColumns() {
    return [ ...this.columnTargets.slice(0, 1), this.maybeTarget, ...this.columnTargets.slice(1) ]
  }
}
