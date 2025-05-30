import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["positionsInput"]

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      filter: ".non-draggable",
      onMove: (evt) => {
        return !evt.related.classList.contains('non-draggable');
      },
      onEnd: (_event) => {
        const newOrder = this.sortable.toArray()
        this.positionsInputTarget.value = newOrder.join(',')
        this.positionsInputTarget.closest('form').requestSubmit()
      }
    })
  }
}