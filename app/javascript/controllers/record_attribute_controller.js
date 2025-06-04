import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["itemIdInput", "propertyIdInput", "valueInput"]

  setAndSubmit(event) {
    const target = event.currentTarget
    const { value, dataset: { itemId, propertyId } } = target

    this.itemIdInputTarget.value = itemId
    this.propertyIdInputTarget.value = propertyId
    this.valueInputTarget.value = value
    this.valueInputTarget.closest("form").requestSubmit();
  }
}