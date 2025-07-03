import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { variantRows: String }
  static targets = ["symbol"]

  connect() {
    this.tbody = this.element.querySelector("tbody");
    this.currentSort = { column: null, direction: 1 };
  }

  sort(event) {
    const column = event.currentTarget.dataset.variantSortColumnValue;
    if (!column) return;
    // Toggle sort direction if same column
    if (this.currentSort.column === column) {
      this.currentSort.direction *= -1;
    } else {
      this.currentSort.column = column;
      this.currentSort.direction = 1;
    }
    const rows = Array.from(this.tbody.querySelectorAll("tr"));
    rows.sort((a, b) => {
      let aValue, bValue;
      if (column === "sku") {
        aValue = a.querySelector('input[name*="[sku]"]').value || "";
        bValue = b.querySelector('input[name*="[sku]"]').value || "";
      } else if (column === "price") {
        aValue = parseFloat(a.querySelector('input[name*="[price]"]').value) || 0;
        bValue = parseFloat(b.querySelector('input[name*="[price]"]').value) || 0;
      } else if (column.startsWith("option-")) {
        // Find the correct option cell by index
        const optionIdx = Array.from(a.children).findIndex(td => td.dataset.optionId === column);
        aValue = optionIdx >= 0 ? a.children[optionIdx].textContent.trim() : "";
        bValue = optionIdx >= 0 ? b.children[optionIdx].textContent.trim() : "";
      }
      if (aValue < bValue) return -1 * this.currentSort.direction;
      if (aValue > bValue) return 1 * this.currentSort.direction;
      return 0;
    });
    // Re-append sorted rows
    rows.forEach(row => this.tbody.appendChild(row));
    this.updateSortSymbols();
  }

  updateSortSymbols() {
    this.symbolTargets.forEach(symbol => {
      const col = symbol.dataset.column;
      const icon = symbol.querySelector("i");
      if (col === this.currentSort.column) {
        icon.className = "fas " + (this.currentSort.direction === 1 ? "fa-chevron-up" : "fa-chevron-down");
      } else {
        icon.className = "";
      }
    });
  }
} 