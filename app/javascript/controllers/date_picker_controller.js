import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  show(event) {
    const input = event.currentTarget
    if (typeof input.showPicker !== "function") return

    try {
      input.showPicker()
    } catch (_error) {
      input.focus()
    }
  }
}
