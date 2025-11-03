import { Controller } from "@hotwired/stimulus"
import { toSentence } from "helpers/text_helpers"

export default class extends Controller {
  #hiddenField

  static targets = [ "label", "item", "hiddenFieldTemplate" ]
  static values = {
    selectPropertyName: { type: String, default: "aria-checked" },
    defaultValue: String,
    noSelectionLabel: { type: String, default: "No selection" },
    labelPrefix: String
  }

  connect() {
    this.refresh()
  }

  change(event) {
    const item = event.target.closest("[role='checkbox']")
    if (item) {
      this.#toggleSelection(item)
    }
  }

  refresh() {
    this.labelTarget.textContent = this.#selectedLabel
    this.#updateHiddenFields()
  }

  clear(event) {
    this.#deselectAll()
    this.#updateHiddenFields()
    this.labelTarget.textContent = this.#selectedLabel
  }

  get #selectedLabel() {
    const selectedValues = this.#selectedValues()
    if (selectedValues.length === 0) {
      return this.noSelectionLabelValue
    }

    const labels = this.#selectedItems().map(item => item.dataset.multiSelectionComboboxLabel)
    const sentence = toSentence(labels, {
      two_words_connector: " or ",
      last_word_connector: ", or "
    })

    return this.hasLabelPrefixValue ? `${this.labelPrefixValue} ${sentence}` : sentence
  }

  #toggleSelection(item) {
    const isSelected = item.getAttribute(this.selectPropertyNameValue) === "true"

    if (isSelected) {
      item.setAttribute(this.selectPropertyNameValue, "false")
    } else {
      item.setAttribute(this.selectPropertyNameValue, "true")
    }

    this.#updateHiddenFields()
    this.labelTarget.textContent = this.#selectedLabel
  }

  #updateHiddenFields() {
    this.#clearHiddenFields()
    this.#addHiddenFields()
  }

  #deselectAll() {
    this.itemTargets.forEach(item => {
      item.setAttribute(this.selectPropertyNameValue, "false")
    })
  }

  #selectedItems() {
    return this.itemTargets.filter(item =>
      item.getAttribute(this.selectPropertyNameValue) === "true"
    )
  }

  #selectedValues() {
    return this.#selectedItems().map(item => item.dataset.multiSelectionComboboxValue)
  }

  #clearHiddenFields() {
    this.element.querySelectorAll('input[type="hidden"]').forEach(field => {
      field.remove()
    })
  }

  #addHiddenFields() {
    this.#selectedValues().forEach(value => {
      const [ field ] = this.hiddenFieldTemplateTarget.content.cloneNode(true).children
      field.removeAttribute("id")
      field.value = value
      this.element.appendChild(field)
    })
  }
}
