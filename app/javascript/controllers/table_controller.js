import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    tableId: String
  }
  
  refreshColumns(event) {
    const propertyId = event.currentTarget.dataset.propertyId;
    const itemIds = Array.from(
      this.element.querySelectorAll('[data-item-id]')
    ).map(el => el.dataset.itemId);
    const csrfMeta = document.querySelector('meta[name="csrf-token"]');
    const token = csrfMeta ? csrfMeta.content : null;

  
    fetch(`${this.tableIdValue}/properties/${propertyId}/refresh_cells`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token,
        'Accept': 'text/vnd.turbo-stream.html',
      },
      body: JSON.stringify({ item_ids: itemIds })
    })
    .then(response => response.text())
    .then(html => Turbo.renderStreamMessage(html))
    .catch(err => console.error("Turbo stream fetch failed:", err));
  }
}