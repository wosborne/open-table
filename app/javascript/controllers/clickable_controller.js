import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("click", this.handleClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.handleClick)
  }

  handleClick(event) {
    const row = event.target.closest("tr[data-url]")
    if (!row) return

    // Optional: prevent clicks on buttons/links inside the row
    if (event.target.closest("a, button")) return

    const url = row.dataset.url
    if (url) Turbo.visit(url)
  }
}