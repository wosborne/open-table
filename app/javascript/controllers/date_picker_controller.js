import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr";

export default class extends Controller {
  static values = {
    format: String,
  }
  connect() {
    flatpickr(this.element, { dateFormat: this.formatValue })
  }
}