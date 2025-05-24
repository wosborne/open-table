import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  typeChanged(event) {
    const selectedType = event.target.value;
    const propertyId = this.element.dataset.propertyId;
    const tableId = this.element.dataset.tableId;
    const frame = document.getElementById(`property-type-fields-${propertyId}`);

    // When the type is changed, we need to update the frame's src to load the new property type fields
    // e.g. tables for linked records, options for select fields, etc.
    frame.src = `${tableId}/properties/${propertyId}/type_fields?type=${selectedType}`;
  }
}