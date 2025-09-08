import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { variantSelectorUrl: String }

  updateFrame(event) {
    const frame = document.getElementById("variant_selector");
    const productId = frame.querySelector('[name="product_id"]').value;
    const optionValueInputs = frame.querySelectorAll('[name="option_value_ids[]"]');
    const optionValueIds = Array.from(optionValueInputs).map(el => el.value).filter(Boolean);

    let url = `${this.variantSelectorUrlValue}?product_id=${productId}`;
    optionValueIds.forEach(id => url += `&option_value_ids[]=${id}`);

    frame.src = url;
  }
} 