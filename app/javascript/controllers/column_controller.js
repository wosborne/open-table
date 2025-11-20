import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["refreshRecordIdsInput"]
  
  refreshCells(_event) {
    const recordIds = Array.from(document.querySelectorAll('[data-record-id]'))
                         .map(el => el.dataset.recordId);

    this.refreshRecordIdsInputTarget.value = JSON.stringify(recordIds)
    this.refreshRecordIdsInputTarget.closest("form").requestSubmit();
  }
}