import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recordIdInput", "propertyIdInput", "valueInput"]

  setAndSubmit(event) {
    const target = event.currentTarget
    const { recordId, propertyId } = target.dataset

    const value =
      target.type === "checkbox"
        ? target.checked ? "1" : "0"
        : target.value

    this.recordIdInputTarget.value = recordId
    this.propertyIdInputTarget.value = propertyId
    this.valueInputTarget.value = value
    this.valueInputTarget.closest("form").requestSubmit();
  }
}