import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { cleanUrlOnClose: Boolean, disableAutofocus: Boolean, open: Boolean }

  connect() {
    this.dialogTarget.addEventListener("close", this.cleanUrl)

    if (this.openValue) {
      requestAnimationFrame(() => this.open())
    }
  }

  disconnect() {
    this.dialogTarget.removeEventListener("close", this.cleanUrl)
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

  cleanUrl = () => {
    if (!this.cleanUrlOnCloseValue || !window.location.search) return

    window.history.replaceState(
      window.history.state,
      "",
      `${window.location.pathname}${window.location.hash}`
    )
  }
}
