import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["imageCard", "destroyField"]

  removeImage(event) {
    const imageCard = event.target.closest("[data-image-manager-target='imageCard']")
    const destroyField = imageCard.querySelector("[data-image-manager-target='destroyField']")
    
    // Mark for destruction
    if (destroyField) {
      destroyField.value = "true"
    }
    
    // Hide the image card with a fade effect
    imageCard.style.transition = "opacity 0.3s ease"
    imageCard.style.opacity = "0"
    
    setTimeout(() => {
      imageCard.style.display = "none"
    }, 300)
  }
}