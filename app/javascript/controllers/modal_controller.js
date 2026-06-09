import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { cleanUrlOnClose: Boolean, disableAutofocus: Boolean, open: Boolean }

  connect() {
    if (!this.hasDialogTarget) return

    this.dialogTarget.addEventListener("close", this.cleanUrl)

    if (this.openValue) {
      requestAnimationFrame(() => this.open())
    }
  }

  disconnect() {
    if (!this.hasDialogTarget) return

    this.dialogTarget.removeEventListener("close", this.cleanUrl)
  }

  open(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return
    if (this.dialogTarget.open) return

    this.dialogTarget.showModal()
    if (this.disableAutofocusValue && this.dialogTarget.contains(document.activeElement)) {
      document.activeElement.blur()
    }
  }

  openDialog(event) {
    this.open_dialog(event)
  }

  open_dialog(event) {
    event.preventDefault()

    const dialogId = event.params.dialogId || event.currentTarget.dataset.modalDialogIdParam
    const dialog = document.getElementById(dialogId)
    if (!dialog) return

    if (this.hasDialogTarget) {
      this.dialogTarget.close()
    }

    requestAnimationFrame(() => dialog.showModal())
  }

  close() {
    if (!this.hasDialogTarget) return

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
