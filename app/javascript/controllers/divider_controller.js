import { Controller } from "@hotwired/stimulus"
import { get, patch } from "@rails/request.js"

const MOVE_ITEM_DATA_TYPE = "x-fizzy/move"
const DIVIDER_ITEM_NODE_NAME = "LI"

export default class extends Controller {
  static targets = [ "divider", "dragImage", "count" ]
  static classes = [ "positioned" ]
  static values = { url: String, method: String, startCount: Number, maxCount: Number }

  connect() {
    this.install()
  }

  install() {
    this.#positionDividerElement(this.startCountValue)
  }

  configureDrag(event) {
    if (event.target == this.dividerTarget) {
      event.dataTransfer.dropEffect = "move"
      event.dataTransfer.setData(MOVE_ITEM_DATA_TYPE, event.target)
      event.dataTransfer.setDragImage(this.dragImageTarget, 0, 0)
    }
  }

  moveDivider(event) {
    if (event.target.nodeName != DIVIDER_ITEM_NODE_NAME) return

    const targetIndex = this.#items.indexOf(event.target)

    if (targetIndex > this.maxCountValue) return

    if (this.#dividerIndex < targetIndex) {
      event.target.after(this.dividerTarget)
    } else {
      event.target.before(this.dividerTarget)
    }

    this.countTarget.textContent = targetIndex
  }

  async persist() {
    if (this.methodValue == "patch") {
      const response = await patch(this.urlValue, { body: { bubble_limit: this.#dividerIndex } })
      const body = await response.json
      Turbo.visit(body.redirect_url, { action: "replace" })
    } else {
      const url = new URL(window.location.href)
      url.searchParams.set("bubble_limit", this.#dividerIndex)
      Turbo.visit(url, { action: "replace" })
    }
  }

  acceptDrop(event) {
    const isDroppable = event.dataTransfer.types.includes(MOVE_ITEM_DATA_TYPE)
    if (isDroppable) event.preventDefault()
  }

  #positionDividerElement(index) {
    if (index == 0) {
      this.#items[0].before(this.dividerTarget)
    } else if (index <= this.#items.length - 1) {
      this.#items[index - 1].after(this.dividerTarget)
    } else {
      this.#items[this.#items.length - 1].after(this.dividerTarget)
    }

    this.dividerTarget.classList.add(this.positionedClass)
  }

  get #items() {
    return Array.from(this.element.children)
  }

  get #dividerIndex() {
    return this.#items.indexOf(this.dividerTarget)
  }
}
