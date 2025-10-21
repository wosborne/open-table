import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["brandSelect", "modelSelect"]
  static values = { 
    modelOptions: Object // Store all model options by brand
  }

  connect() {
    console.log("Cascading select controller connected")
    this.originalModelOptions = this.modelOptionsValue
    this.updateModelOptions()
  }

  brandChanged() {
    this.updateModelOptions()
  }

  updateModelOptions() {
    const selectedBrand = this.brandSelectTarget.value
    const modelSelect = this.modelSelectTarget

    // Clear existing options except the first one
    while (modelSelect.options.length > 1) {
      modelSelect.remove(1)
    }

    if (selectedBrand && this.originalModelOptions[selectedBrand]) {
      // Add filtered model options for the selected brand
      this.originalModelOptions[selectedBrand].forEach(model => {
        const option = new Option(model, model)
        modelSelect.add(option)
      })
      
      // Enable the model select
      modelSelect.disabled = false
      modelSelect.querySelector('option[value=""]').textContent = "Select Model..."
    } else {
      // Disable the model select if no brand selected
      modelSelect.disabled = true
      modelSelect.querySelector('option[value=""]').textContent = "Select Brand first..."
    }
  }
}