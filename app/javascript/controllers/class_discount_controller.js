import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "fields"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasFieldsTarget || !this.hasToggleTarget) return

    this.fieldsTarget.hidden = !this.toggleTarget.checked
  }
}
