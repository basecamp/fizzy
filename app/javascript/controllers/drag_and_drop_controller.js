import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item", "container" ]
  static classes = [ "draggedItem", "hoverContainer" ]

  // Actions

  async dragStart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.dropEffect = "move"
    event.dataTransfer.setData("37ui/move", event.target)

    await nextFrame()
    this.dragItem = this.#itemContaining(event.target)
    this.sourceContainer = this.#containerContaining(this.dragItem)
    this.originalDraggedItemCssVariable = this.#containerCssVariableFor(this.sourceContainer)
    this.dragItem.classList.add(this.draggedItemClass)
  }

  dragOver(event) {
    event.preventDefault()
    if (!this.dragItem) { return }

    const container = this.#containerContaining(event.target)
    this.#clearContainerHoverClasses()

    if (!container) { return }

    if (container !== this.sourceContainer) {
      container.classList.add(this.hoverContainerClass)
      this.#applyContainerCssVariableToDraggedItem(container)
    } else {
      this.#restoreOriginalDraggedItemCssVariable()
    }
  }

  async drop(event) {
    const targetContainer = this.#containerContaining(event.target)

    if (!targetContainer || targetContainer === this.sourceContainer) { return }

    this.wasDropped = true
    this.#increaseCounter(targetContainer)
    this.#decreaseCounter(this.sourceContainer)

    const sourceContainer = this.sourceContainer
    this.#insertDraggedItem(targetContainer, this.dragItem)
    await this.#submitDropRequest(this.dragItem, targetContainer)
    this.#reloadSourceFrame(sourceContainer)
  }

  dragEnd() {
    this.dragItem.classList.remove(this.draggedItemClass)
    this.#clearContainerHoverClasses()

    if (!this.wasDropped) {
      this.#restoreOriginalDraggedItemCssVariable()
    }

    this.sourceContainer = null
    this.dragItem = null
    this.wasDropped = false
    this.originalDraggedItemCssVariable = null
  }

  #itemContaining(element) {
    return this.itemTargets.find(item => item.contains(element) || item === element)
  }

  #containerContaining(element) {
    return this.containerTargets.find(container => container.contains(element) || container === element)
  }

  #clearContainerHoverClasses() {
    this.containerTargets.forEach(container => container.classList.remove(this.hoverContainerClass))
  }

  #applyContainerCssVariableToDraggedItem(container) {
    const cssVariable = this.#containerCssVariableFor(container)
    if (cssVariable) {
      this.dragItem.style.setProperty(cssVariable.name, cssVariable.value)
    }
  }

  #restoreOriginalDraggedItemCssVariable() {
    if (this.originalDraggedItemCssVariable) {
      const { name, value } = this.originalDraggedItemCssVariable
      this.dragItem.style.setProperty(name, value)
    }
  }

  #containerCssVariableFor(container) {
    const { dragAndDropCssVariableName, dragAndDropCssVariableValue } = container.dataset
    if (dragAndDropCssVariableName && dragAndDropCssVariableValue) {
      return { name: dragAndDropCssVariableName, value: dragAndDropCssVariableValue }
    }
    return null
  }

  #increaseCounter(container) {
    this.#modifyCounter(container, count => count + 1)
  }

  #decreaseCounter(container) {
    this.#modifyCounter(container, count => Math.max(0, count - 1))
  }

  #modifyCounter(container, fn) {
    const counterElement = container.querySelector("[data-drag-and-drop-counter]")
    if (counterElement) {
      const currentValue = counterElement.textContent.trim()

      if (!/^\d+$/.test(currentValue)) return

      counterElement.textContent = fn(parseInt(currentValue))
    }
  }

  #insertDraggedItem(container, item) {
    const itemContainer = container.querySelector("[data-drag-drop-item-container]")
    const topItems = itemContainer.querySelectorAll("[data-drag-and-drop-top]")
    const firstTopItem = topItems[0]
    const lastTopItem = topItems[topItems.length - 1]

    const isTopItem = item.hasAttribute("data-drag-and-drop-top")
    const referenceItem = isTopItem ? firstTopItem : lastTopItem

    if (referenceItem) {
      referenceItem[isTopItem ? "before" : "after"](item)
    } else {
      itemContainer.prepend(item)
    }
  }

  async #submitDropRequest(item, container) {
    const body = new FormData()
    const id = item.dataset.id
    const url = container.dataset.dragAndDropUrl.replaceAll("__id__", id)

    return post(url, { body, headers: { Accept: "text/vnd.turbo-stream.html" } })
  }

  #reloadSourceFrame(sourceContainer) {
    const frame = sourceContainer.querySelector("[data-drag-and-drop-refresh]")
    if (frame) frame.reload()
  }
}
