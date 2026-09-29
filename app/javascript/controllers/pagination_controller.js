import { Controller } from "@hotwired/stimulus"
import { createElement } from "helpers/html_helpers"
import { delay, nextEvent } from "helpers/timing_helpers"
import { keepingScrollPosition } from "helpers/scroll_helpers"
import { get } from "@rails/request.js"

const DELAY_BEFORE_OBSERVING = 400

export default class extends Controller {
  static targets = [ "paginationLink" ]
  static values = {
    paginateOnIntersection: { type: Boolean, default: false },
    discardFrame: Boolean,
    manualActivation: Boolean
  }

  initialize() {
    if (!this.manualActivation) {
      this.activate()
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async activate() {
    await delay(DELAY_BEFORE_OBSERVING)

    if (this.paginateOnIntersectionValue) {
      this.observer = new IntersectionObserver(this.#intersect, { rootMargin: "300px", threshold: 1 })
    }
  }

  async paginationLinkTargetConnected(linkElement) {
    if (this.paginateOnIntersectionValue) {
      await delay(DELAY_BEFORE_OBSERVING)
      this.observer?.observe(linkElement)
    }
  }

  paginationLinkTargetDisconnected(linkElement) {
    this.observer?.unobserve(linkElement)
  }

  // Actions

  loadPage({ target }) {
    this.#loadPaginationLink(target)
  }

  // Private

  #intersect = (entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting && entry.intersectionRatio === 1 && !this.#isLoaded(entry.target)) {
        this.#loadPaginationLink(entry.target)
      }
    }
  }

  // Links stay observed so a page whose frame a morph removed loads again.
  #isLoaded(linkElement) {
    return this.element.querySelector(`turbo-frame#${linkElement.dataset.frame}`) !== null
  }

  #loadPaginationLink(linkElement) {
    keepingScrollPosition(this.#closestSiblingTo(linkElement) || linkElement.parentNode, this.#expandPaginationLink(linkElement))
  }

  #closestSiblingTo(element) {
    return element.nextElementSibling || element.previousElementSibling
  }

  async #expandPaginationLink(linkElement) {
    linkElement.setAttribute("aria-busy", "true")

    if (this.discardFrameValue) {
      await this.#replacePaginationLinkWithFrameContents(linkElement)
    } else {
      await this.#replacePaginationLinkWithFrame(linkElement)
    }

    linkElement.removeAttribute("aria-busy")
  }

  async #replacePaginationLinkWithFrameContents(linkElement) {
    linkElement.outerHTML = await this.#loadHtmlFrom(linkElement)
  }

  async #loadHtmlFrom(linkElement) {
    const response = await get(linkElement.href, { responseKind: "html" })
    const html = await response.text
    const doc = new DOMParser().parseFromString(html, "text/html")
    const element = doc.querySelector(`turbo-frame#${linkElement.dataset.frame}`)
    return element ? element.innerHTML.trim() : ""
  }

  #replacePaginationLinkWithFrame(linkElement) {
    const turboFrame = this.#buildTurboFrameFor(linkElement)
    this.#insertTurboFrameAtPosition(linkElement, turboFrame)
  }

  #buildTurboFrameFor(linkElement) {
    const turboFrame = createElement("turbo-frame", {
      id: linkElement.dataset.frame,
      src: linkElement.href,
      refresh: "morph",
      target: "_top"
    })

    this.#keepScrollPositionOnFrameRender(turboFrame, linkElement)

    return turboFrame
  }

  async #keepScrollPositionOnFrameRender(turboFrame, linkElement) {
    await nextEvent(turboFrame, "turbo:before-frame-render")

    keepingScrollPosition(linkElement, nextEvent(turboFrame, "turbo:frame-render"))
  }

  #insertTurboFrameAtPosition(linkElement, turboFrame) {
    const container = linkElement.parentNode.parentNode

    if (linkElement.parentNode.firstElementChild === linkElement) {
      container.prepend(turboFrame)
    } else {
      container.append(turboFrame)
    }
  }
}
