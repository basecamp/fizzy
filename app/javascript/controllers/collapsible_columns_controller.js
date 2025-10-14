import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "collapsed" ]
  static targets = [ "column", "button" ]

  connect() {
    this.#restoreColumns()
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
      const key = this.#localStorageKeyFor(column)
      if (localStorage.getItem(key)) {
        this.#expand(column)
      }
    })
  }

  #localStorageKeyFor(column) {
    return `expand-${column.getAttribute("id")}`
  }
}
