import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";
import { nextFrame } from "helpers/timing_helpers";

export default class extends Controller {
  static targets = ["item", "container"];
  static classes = ["draggedItem", "hoverContainer"];

  // Actions

  async dragStart(event) {
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.dropEffect = "move";
    event.dataTransfer.setData("37ui/move", event.target);

    await nextFrame();
    this.dragItem = this.#itemContaining(event.target);
    this.sourceContainer = this.#containerContaining(this.dragItem);
    this.originalDraggedItemCssVariable = this.#containerCssVariableFor(
      this.sourceContainer,
    );
    this.dragItem.classList.add(this.draggedItemClass);
  }

  dragOver(event) {
    event.preventDefault();
    if (!this.dragItem) {
      return;
    }

    const container = this.#containerContaining(event.target);
    this.#clearContainerHoverClasses();

    if (!container) {
      return;
    }

    this.#repositionDraggedItem(container, event.clientY);

    if (container !== this.sourceContainer) {
      container.classList.add(this.hoverContainerClass);
      this.#applyContainerCssVariableToDraggedItem(container);
    } else {
      this.#restoreOriginalDraggedItemCssVariable();
    }
  }

  async drop(event) {
    const targetContainer = this.#containerContaining(event.target);

    if (!targetContainer) {
      return;
    }

    this.wasDropped = true;
    const sourceContainer = this.sourceContainer;
    const movedAcrossContainers = targetContainer !== sourceContainer;

    if (movedAcrossContainers) {
      this.#increaseCounter(targetContainer);
      this.#decreaseCounter(sourceContainer);
    }

    this.#repositionDraggedItem(targetContainer, event.clientY);
    await this.#submitDropRequest(this.dragItem, targetContainer);

    if (movedAcrossContainers) this.#reloadSourceFrame(sourceContainer);
  }

  dragEnd() {
    this.dragItem.classList.remove(this.draggedItemClass);
    this.#clearContainerHoverClasses();

    if (!this.wasDropped) {
      this.#restoreOriginalDraggedItemCssVariable();
    }

    this.sourceContainer = null;
    this.dragItem = null;
    this.wasDropped = false;
    this.originalDraggedItemCssVariable = null;
  }

  #itemContaining(element) {
    return this.itemTargets.find(
      (item) => item.contains(element) || item === element,
    );
  }

  #containerContaining(element) {
    return this.containerTargets.find(
      (container) => container.contains(element) || container === element,
    );
  }

  #clearContainerHoverClasses() {
    this.containerTargets.forEach((container) =>
      container.classList.remove(this.hoverContainerClass),
    );
  }

  #applyContainerCssVariableToDraggedItem(container) {
    const cssVariable = this.#containerCssVariableFor(container);
    if (cssVariable) {
      this.dragItem.style.setProperty(cssVariable.name, cssVariable.value);
    }
  }

  #restoreOriginalDraggedItemCssVariable() {
    if (this.originalDraggedItemCssVariable) {
      const { name, value } = this.originalDraggedItemCssVariable;
      this.dragItem.style.setProperty(name, value);
    }
  }

  #containerCssVariableFor(container) {
    const { dragAndDropCssVariableName, dragAndDropCssVariableValue } =
      container.dataset;
    if (dragAndDropCssVariableName && dragAndDropCssVariableValue) {
      return {
        name: dragAndDropCssVariableName,
        value: dragAndDropCssVariableValue,
      };
    }
    return null;
  }

  #increaseCounter(container) {
    this.#modifyCounter(container, (count) => count + 1);
  }

  #decreaseCounter(container) {
    this.#modifyCounter(container, (count) => Math.max(0, count - 1));
  }

  #modifyCounter(container, fn) {
    const counterElement = container.querySelector(
      "[data-drag-and-drop-counter]",
    );
    if (counterElement) {
      const currentValue = counterElement.textContent.trim();

      if (!/^\d+$/.test(currentValue)) return;

      counterElement.textContent = fn(parseInt(currentValue));
    }
  }

  #repositionDraggedItem(container, clientY) {
    const itemContainer = container.querySelector(
      "[data-drag-drop-item-container]",
    );
    if (!itemContainer) return;

    const item = this.dragItem;
    const topItems = itemContainer.querySelectorAll("[data-drag-and-drop-top]");
    const firstTopItem = topItems[0];
    const lastTopItem = topItems[topItems.length - 1];

    const isTopItem = item.hasAttribute("data-drag-and-drop-top");
    const candidates = Array.from(
      itemContainer.querySelectorAll('[data-drag-and-drop-target="item"]'),
    )
      .filter((candidate) => candidate !== item)
      .filter(
        (candidate) =>
          candidate.hasAttribute("data-drag-and-drop-top") === isTopItem,
      );

    const referenceItem = candidates.find((candidate) => {
      const { top, height } = candidate.getBoundingClientRect();
      return clientY < top + height / 2;
    });

    if (referenceItem) return referenceItem.before(item);

    if (candidates.length > 0)
      return candidates[candidates.length - 1].after(item);

    if (isTopItem) {
      const firstNonTopItem = itemContainer.querySelector(
        '[data-drag-and-drop-target="item"]:not([data-drag-and-drop-top])',
      );
      return firstNonTopItem
        ? firstNonTopItem.before(item)
        : itemContainer.prepend(item);
    }

    return lastTopItem ? lastTopItem.after(item) : itemContainer.prepend(item);
  }

  async #submitDropRequest(item, container) {
    const body = new FormData();
    const id = item.dataset.id;
    const url = container.dataset.dragAndDropUrl.replaceAll("__id__", id);

    const { beforeId, afterId } = this.#neighborIdsFor(item);
    if (beforeId) body.append("before_id", beforeId);
    if (afterId) body.append("after_id", afterId);

    return post(url, {
      body,
      headers: { Accept: "text/vnd.turbo-stream.html" },
    });
  }

  #neighborIdsFor(item) {
    const isTopItem = item.hasAttribute("data-drag-and-drop-top");

    const matchesGroup = (candidate) => {
      if (!candidate) return false;
      if (candidate.getAttribute("data-drag-and-drop-target") !== "item")
        return false;
      return candidate.hasAttribute("data-drag-and-drop-top") === isTopItem;
    };

    let previous = item.previousElementSibling;
    while (previous && !matchesGroup(previous))
      previous = previous.previousElementSibling;

    let next = item.nextElementSibling;
    while (next && !matchesGroup(next)) next = next.nextElementSibling;

    return { beforeId: next?.dataset?.id, afterId: previous?.dataset?.id };
  }

  #reloadSourceFrame(sourceContainer) {
    const frame = sourceContainer.querySelector("[data-drag-and-drop-refresh]");
    if (frame) frame.reload();
  }
}
