import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAll", "selectedCount", "deleteInput", "deleteButton"]
  static values = {
    tableId: String
  }

  toggleAll(event) {
    const checked = event.currentTarget.checked;
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = checked; // or false, or toggle logic
    });
    this.updateSelectedCount();
  }

  toggleItem(event) {
    event.stopPropagation();
    const checkbox = event.currentTarget.querySelector('[data-table-target="checkbox"]');
    checkbox.checked = !checkbox.checked;
    this.updateSelectAll()
    this.updateSelectedCount();
  }

  onCheckboxChange(event) {
    this.updateSelectAll()
    this.updateSelectedCount();
  }

  updateSelectAll() {
    const atLeastOne = this.checkboxTargets.some(checkbox => checkbox.checked);
    const allChecked = this.checkboxTargets.every((checkbox) => checkbox.checked);
    this.selectAllTarget.checked = allChecked;
    this.selectAllTarget.indeterminate = atLeastOne && !allChecked;
  }

  selectRow(event) {
    const checkbox = event.currentTarget.querySelector('[data-table-target="checkbox"]');
    if (checkbox) {
      this.uncheckAll();
      checkbox.checked = true;
      this.selectAllTarget.indeterminate = true;
    }
    this.updateSelectedCount();
  }

  uncheckAll() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false;
    });
    this.selectAllTarget.checked = false;
    this.selectAllTarget.indeterminate = false;
    this.updateSelectedCount();
  }

  updateSelectedCount() {
    const count = this.checkboxTargets.filter(checkbox => checkbox.checked).length;
    this.selectedCountTarget.textContent = count;
    this.updateDeleteInput()
    if (count > 0) {
      this.deleteButtonTarget.classList.add("is-danger","is-outlined");
      this.deleteButtonTarget.disabled = false
    } else {
      this.deleteButtonTarget.classList.remove("is-danger","is-outlined");
      this.deleteButtonTarget.disabled = true
    }
  }

  updateDeleteInput() {
    const checkedIds = this.checkboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value);
    this.deleteInputTarget.value = checkedIds
  }

  stopPropagation(event) {
    event.stopPropagation();
  }
}