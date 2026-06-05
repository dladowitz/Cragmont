import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { disableAutofocus: Boolean, open: Boolean }

  connect() {
    if (this.openValue) {
      requestAnimationFrame(() => this.open())
    }
  }

  open(event) {
    event?.preventDefault()
    if (this.dialogTarget.open) return

    this.dialogTarget.showModal()
    if (this.disableAutofocusValue && this.dialogTarget.contains(document.activeElement)) {
      document.activeElement.blur()
    }
  }

  close() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }
}
