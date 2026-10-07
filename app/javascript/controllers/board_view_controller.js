import { Controller } from "@hotwired/stimulus"
import { nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  connect() {
    this.storageKey = `board-view:${location.pathname}${location.search}`
    try { this.snapshot = JSON.parse(sessionStorage.getItem(this.storageKey)) } catch { }
  }

  disconnect() {
    this.cancelled = true
  }

  remember() {
    if (this.restoring && !this.cancelled) { return }

    const columns = Array.from(this.element.querySelectorAll(".cards.is-expanded"))
    const snapshot = {
      expanded: columns.map(column => column.id),
      x: this.element.scrollLeft,
      windowX: window.scrollX, windowY: window.scrollY,
      mainY: document.getElementById("main").scrollTop,
      columns: columns.map(column => ({
        id: column.id,
        y: column.querySelector(".cards__list")?.scrollTop || 0,
        pages: Math.max(1, ...Array.from(column.querySelectorAll("turbo-frame[id*='-pagination-contents-']"),
          frame => Number(frame.id.match(/-contents-(\d+)$/)?.[1]) || 1))
      }))
    }
    try { sessionStorage.setItem(this.storageKey, JSON.stringify(snapshot)) } catch { }
  }

  cancelRestoration() {
    if (this.restoring) { this.cancelled = true }
  }

  async restore() {
    if (!this.snapshot || this.restoring || this.restored) { return }
    this.restoring = true

    try {
      const controller = this.application.getControllerForElementAndIdentifier(this.element, "collapsible-columns")
      await controller.restoreExpandedColumns(this.snapshot.expanded)

      await Promise.all(this.snapshot.columns.map(column => this.#restorePages(column)))
      // Let remembered keyboard selection settle before restoring the exact viewport.
      await nextFrame()
      await nextFrame()
      if (this.cancelled || !this.element.isConnected) { return }

      this.snapshot.columns.forEach(({ id, y }) => {
        const list = document.getElementById(id)?.querySelector(".cards__list")
        if (list) { list.scrollTop = y }
      })
      this.element.scrollLeft = this.snapshot.x
      document.getElementById("main").scrollTop = this.snapshot.mainY
      window.scrollTo({ left: this.snapshot.windowX, top: this.snapshot.windowY, behavior: "instant" })
    } catch {
      // A failed page request must not prevent using the board.
    } finally {
      this.restoring = false
      this.restored = true
    }
  }

  async #restorePages({ id, pages }) {
    const column = document.getElementById(id)
    if (!column) { return }
    const frame = column.querySelector("turbo-frame[src]")
    if (frame) { await frame.loaded }
    await nextFrame()

    for (let page = 2; page <= pages && !this.cancelled && this.element.isConnected; page++) {
      const link = Array.from(column.querySelectorAll("[data-pagination-target='paginationLink']"))
        .find(link => Number(link.getAttribute("aria-label")?.match(/\d+/)?.[0]) === page)
      if (!link) { break }

      let nextPage = document.getElementById(link.dataset.frame)
      if (!nextPage) {
        const pagination = this.application.getControllerForElementAndIdentifier(link.closest("[data-controller~='pagination']"), "pagination")
        if (!pagination) { break }
        pagination.loadPage({ target: link })
        nextPage = document.getElementById(link.dataset.frame)
      }
      if (nextPage) { await nextPage.loaded }
      await nextFrame()
    }
  }
}
