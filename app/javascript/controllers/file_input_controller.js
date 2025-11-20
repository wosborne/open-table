import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "fileName"]

  updateFileName() {
    const files = this.inputTarget.files

    if (files.length === 0) {
      this.fileNameTarget.textContent = "No files selected"
    } else if (files.length === 1) {
      this.fileNameTarget.textContent = files[0].name
    } else {
      this.fileNameTarget.textContent = `${files.length} files selected`
    }
  }
}