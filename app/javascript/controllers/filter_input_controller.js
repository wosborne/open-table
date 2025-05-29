import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    viewId: String,
    index: String
  }
  
  propertyChanged(event) {
    const propertyId = event.target.value;
    const viewId = this.tableIdValue;
    
    this.inputTarget.src = `${viewId}/filter_field/?property_id=${propertyId}?&index=${this.indexValue}`;
  }
}