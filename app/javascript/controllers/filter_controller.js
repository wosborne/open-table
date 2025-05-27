// app/javascript/controllers/filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["propertySelect", "valueInput", "form", "hiddenInput"]
  
  addFilter(event) {
    event.preventDefault()

    const key = this.propertySelectTarget.value
    const value = this.valueInputTarget.value.trim()
    if (!key || !value) return

    const filters = this._getFilters()
    filters[key] = value
    this._updateAndSubmit(filters)
  }

  removeFilter(event) {
    const key = event.target.dataset.filterKey
    if (!key) return

    const filters = this._getFilters()
    delete filters[key]
    this._updateAndSubmit(filters)
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
