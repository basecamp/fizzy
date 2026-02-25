import { Controller } from "@hotwired/stimulus"
import { nextFrame, debounce } from "helpers/timing_helpers";
import { isNative } from "helpers/platform_helpers";

export default class extends Controller {
  static classes = [ "collapsed", "expanded", "noTransitions", "titleNotVisible" ]
  static targets = [ "column", "button", "title", "maybeColumn" ]
  static values = {
    board: String,
    desktopBreakpoint: { type: String, default: "(min-width: 640px)" }
  }

  initialize() {
    this.restoreState = debounce(this.restoreState.bind(this), 10)
  }

  async connect() {
    this.mediaQuery = window.matchMedia(this.desktopBreakpointValue)
    this.handlePlatform = this.#handlePlatform.bind(this)
    this.mediaQuery.addEventListener("change", this.handlePlatform)

    await this.#restoreColumnsDisablingTransitions()
    this.#setupIntersectionObserver()
  }

  disconnect() {
    if (this._intersectionObserver) {
      this._intersectionObserver.disconnect()
      this._intersectionObserver = null
    }
    this.mediaQuery.removeEventListener("change", this.handlePlatform)
  }

  toggle({ target }) {
    const column = target.closest('[data-collapsible-columns-target~="column"]')
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
    if (this.#isDesktop && this.#isCollapsed(target)) {
      this.#collapseAllExcept(target)
      this.#expand({ column: target })
    }
  }

  async #restoreColumnsDisablingTransitions() {
    this.#disableTransitions()
    this.#restoreColumns()
    this.#handlePlatform()

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
      this.#expand({ column })
    } else {
      this.#collapse(column)
    }
  }

  #collapseAllExcept(clickedColumn) {
    const columns = this.#isDesktop ? this.columnTargets.filter(c => c !== this.maybeColumnTarget) : this.columnTargets

    columns.forEach(column => {
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

    this.#buttonFor(column)?.setAttribute("aria-expanded", "false")
    column.classList.remove(this.expandedClass)
    column.classList.add(this.collapsedClass)
    localStorage.removeItem(key)
  }

  #expand({ column, saveState = true, scrollBehavior = "smooth" }) {
    this.#buttonFor(column)?.setAttribute("aria-expanded", "true")
    column.classList.remove(this.collapsedClass)
    column.classList.add(this.expandedClass)

    if (saveState) {
      const key = this.#localStorageKeyFor(column)
      localStorage.setItem(key, true)
    }

    if (window.matchMedia('(max-width: 639px)').matches) {
      column.scrollIntoView({ behavior: scrollBehavior, inline: "center" })
    }
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
      this.#collapseAllExcept(column)
      this.#expand({ column, scrollBehavior: isNative() ? "instant" : "smooth" })
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

  get #isDesktop() {
    return this.mediaQuery?.matches
  }

  #handlePlatform() {
    this.#isDesktop ? this.#handleDesktopMode() : this.#handleMobileMode()
  }

  async #handleDesktopMode() {
    this.#expand({ column: this.maybeColumnTarget, saveState: false })
    this.#maybeButton.setAttribute("disabled", true)
  }

  #handleMobileMode() {
    this.#maybeButton.removeAttribute("disabled")

    const expandedColumn = this.columnTargets.find(column => column !== this.maybeColumnTarget && !this.#isCollapsed(column))

    if (expandedColumn) {
      this.#collapseAllExcept(expandedColumn)
    } else {
      this.#collapseAllExcept(this.maybeColumnTarget)
      this.#expand({ column: this.maybeColumnTarget, saveState: false })
    }
  }

  get #maybeButton() {
    return this.maybeColumnTarget.querySelector('[data-collapsible-columns-target="button"]')
  }
}
