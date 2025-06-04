import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["refreshItemIdsInput"]
  
  refreshCells(_event) {
    const itemIds = Array.from(document.querySelectorAll('[data-item-id]'))
                         .map(el => el.dataset.itemId);

    this.refreshItemIdsInputTarget.value = JSON.stringify(itemIds)
    this.refreshItemIdsInputTarget.closest("form").requestSubmit();
  }
}