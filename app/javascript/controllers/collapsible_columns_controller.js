import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "collapsed" ]
  static targets = [ "column" ]

  toggle(event) {
    const clickedColumn = event.target.closest('[data-collapsible-columns-target="column"]')

    if (!clickedColumn) return

    const isCurrentlyCollapsed = clickedColumn.classList.contains(this.collapsedClass)

    this.columnTargets.forEach(column => {
      column.classList.add(this.collapsedClass)
    })

    if (isCurrentlyCollapsed) {
      clickedColumn.classList.remove(this.collapsedClass)
    }
  }

  preventToggle(event) {
    if (event.detail.attributeName === "class") {
      event.preventDefault()
    }
  }
}
