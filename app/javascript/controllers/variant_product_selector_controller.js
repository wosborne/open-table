import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { productOptionsUrl: String }

  updateProductOptions(event) {
    const productId = event.target.value
    const frame = document.getElementById("product_options")
    
    if (productId && frame) {
      const url = `${this.productOptionsUrlValue}?product_id=${productId}`
      frame.src = url
    }
  }
}