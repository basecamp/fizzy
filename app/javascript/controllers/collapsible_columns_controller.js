import { Controller } from "@hotwired/stimulus"
import { nextFrame, debounce } from "helpers/timing_helpers";

export default class extends Controller {
  static classes = [ "collapsed", "noTransitions" ]
  static targets = [ "column", "button", "title" ]
  static values = {
    board: String
  }

  initialize() {
    this.restoreState = debounce(this.restoreState.bind(this), 10)
  }

  async connect() {
    await this.#restoreColumnsDisablingTransitions()
  }

  toggle({ target }) {
    const column = target.closest('[data-collapsible-columns-target="column"]')
    this.#toggleColumn(column);
  }

  preventToggle(event) {
    if (event.target.hasAttribute("data-collapsible-columns-target") && event.detail.attributeName === "class") {
      event.preventDefault()
    }
  }

  async restoreState(event) {
    await nextFrame()
    await this.#restoreColumnsDisablingTransitions()
  }

  focusOnColumn({ target }) {
    if (this.#isCollapsed(target)) {
      this.#collapseAllExcept(target)
      this.#expand(target)
    }
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
}
