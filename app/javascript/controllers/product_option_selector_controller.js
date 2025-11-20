import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { variantSelectorUrl: String }

  updateFrame(event) {
    const frame = document.getElementById("variant_selector");
    const productId = frame.querySelector('[name="product_id"]').value;

    if (productId) {
      const url = `${this.variantSelectorUrlValue}?product_id=${productId}`;
      frame.src = url;
    }
  }
} 