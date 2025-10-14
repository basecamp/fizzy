import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers";
import { post } from "@rails/request.js"

export default class extends Controller {
  static classes = ["filtersSet"]
  static targets = ["field", "form"]
  static values = { refreshUrl: String, noFilteringUrl: String, cardsUrl: String }

  initialize() {
    this.debouncedToggle = debounce(this.#toggle.bind(this), 50)
  }

  connect() {
    this.#toggle()
  }

  change(event) {
    this.#toggle()
    this.#refreshSaveToggleButton()
  }

  resetIfNoFiltering(event) {
    if (!this.#hasFiltersSet) {
      this.#showNoFilteringUrl()
      event.stopImmediatePropagation()
    }
  }

  async fieldTargetConnected(field) {
    this.debouncedToggle()
  }

  submitToGenericCardsView() {
    this.formTarget.action = this.cardsUrlValue
    this.formTarget.dataset.turboFrame = "top"
    this.formTarget.requestSubmit()
  }

  #toggle() {
    this.element.classList.toggle(this.filtersSetClass, this.#hasFiltersSet)
  }

  get #hasFiltersSet() {
    return this.fieldTargets.some(field => this.#isFieldSet(field))
  }

  #isFieldSet(field) {
    const value = field.value?.trim()

    if (!value) return false

    const defaultValue = this.#defaultValueForField(field)
    return defaultValue ? value !== defaultValue : true
  }

  #defaultValueForField(field) {
    const comboboxContainer = field.closest("[data-combobox-default-value-value]")
    return comboboxContainer?.dataset?.comboboxDefaultValueValue
  }

  #refreshSaveToggleButton() {
    post(this.refreshUrlValue, {
      body: this.#collectFilterFormData(),
      responseKind: "turbo-stream"
    })
  }

  #collectFilterFormData() {
    const formData = new FormData()

    this.formTargets.forEach(form => {
      const hiddenFields = form.querySelectorAll('input[type="hidden"]:not([disabled])[name]')
      hiddenFields.forEach(field => {
        formData.append(field.name, field.value)
      })
    })

    return formData
  }

  #showNoFilteringUrl() {
    Turbo.visit(this.noFilteringUrlValue, { frame: "cards_container", action: "advance" })
  }
}
