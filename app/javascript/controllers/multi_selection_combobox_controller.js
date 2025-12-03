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
    this.#updateFilterShow()
  }

  clear(event) {
    this.#deselectAll()
    this.#updateHiddenFields()
    this.labelTarget.textContent = this.#selectedLabel
    this.#updateFilterShow()
  }

  get #selectedLabel() {
    const selectedValues = this.#selectedValues()
    if (selectedValues.length === 0) {
      return this.noSelectionLabelValue
    }

    const labels = this.#selectedItems.map(item => item.dataset.multiSelectionComboboxLabel)
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
      if (this.isAnExclusiveSelectionItemInvolved(item)) {
        this.#deselectAll()
      }

      item.setAttribute(this.selectPropertyNameValue, "true")
    }

    this.#updateHiddenFields()
    if (item.dataset.multiSelectionFieldName) {
      this.#renameHiddenFields(item.dataset.multiSelectionFieldName)
    }
    this.labelTarget.textContent = this.#selectedLabel
  }

  isAnExclusiveSelectionItemInvolved(item) {
    return this.#isExclusiveSelection(item) || Array.from(this.#selectedItems).some((item) => this.#isExclusiveSelection(item))
  }

  #isExclusiveSelection(item) {
    return item.dataset.multiSelectionExclusive === "true"
  }

  #updateHiddenFields() {
    this.#clearHiddenFields()
    this.#addHiddenFields()
    this.#updateFilterShow()
  }

  #deselectAll() {
    this.itemTargets.forEach(item => {
      item.setAttribute(this.selectPropertyNameValue, "false")
    })
  }

  get #selectedItems() {
    return this.itemTargets.filter(item =>
      item.getAttribute(this.selectPropertyNameValue) === "true"
    )
  }

  #selectedValues() {
    return this.#selectedItems.map(item => item.dataset.multiSelectionComboboxValue)
  }

  #clearHiddenFields() {
    this.#hiddenFields.forEach(field => {
      field.remove()
    })
  }

  #renameHiddenFields(fieldName) {
    this.#hiddenFields.forEach(field => {
      field.setAttribute("name", fieldName)
    })
  }

  get #hiddenFields() {
    return this.element.querySelectorAll("input[type='hidden']")
  }

  #addHiddenFields() {
    this.#selectedValues().forEach(value => {
      const [ field ] = this.hiddenFieldTemplateTarget.content.cloneNode(true).children
      field.removeAttribute("id")
      field.value = value
      this.element.appendChild(field)
    })
  }

  #updateFilterShow() {
    const hasSelection = this.#selectedValues().length > 0
    this.element.setAttribute("data-filter-show", hasSelection)
  }
}
