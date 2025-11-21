// app/javascript/controllers/model_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["attributeSelect", "valueInput", "form", "hiddenInput", "filterTag"]
  
  connect() {
    this._updateInputState()
  }

  addFilter(event) {
    event.preventDefault()
    
    const attribute = this.attributeSelectTarget.value
    const value = this.valueInputTarget.value.trim()
    if (!attribute || !value) return

    const filters = this._getFilters()
    filters[attribute] = value
    this._updateAndSubmit(filters)
  }

  removeFilter(event) {
    const attribute = event.target.dataset.filterAttribute
    if (!attribute) return

    const filters = this._getFilters()
    delete filters[attribute]
    this._updateAndSubmit(filters)
  }

  attributeSelectTargetConnected() {
    this.attributeSelectTarget.addEventListener('change', () => {
      this._updateInputState()
    })
  }

  _updateInputState() {
    const hasSelection = this.attributeSelectTarget.value !== ""
    this.valueInputTarget.disabled = !hasSelection
    this.valueInputTarget.placeholder = hasSelection ? "Enter value" : "Select an attribute first"
    
    if (!hasSelection) {
      this.valueInputTarget.value = ""
    }
  }

  _getFilters() {
    try {
      return this.hiddenInputTarget.value ? JSON.parse(this.hiddenInputTarget.value) : {}
    } catch (e) {
      return {}
    }
  }

  _updateAndSubmit(filters) {
    this.hiddenInputTarget.value = JSON.stringify(filters)
    this.formTarget.requestSubmit()
  }
}