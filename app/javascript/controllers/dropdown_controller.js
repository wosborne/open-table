import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    document.addEventListener("click", (event) => {
      if (!this.dropdownTarget.contains(event.target)) {
        this.close()
      }
    })
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        this.close()
      }
    })
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.close)
  }

  toggle() {
    this.dropdownTarget.classList.toggle("is-active")
  }


  close() {
    this.dropdownTarget.classList.remove("is-active")
  }
}
