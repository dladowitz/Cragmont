import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "label", "panel", "search", "option", "empty"]
  static values = { placeholder: String }

  connect() {
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.boundSyncDisabled = this.syncDisabled.bind(this)
    document.addEventListener("click", this.boundCloseOnOutsideClick)
    this.element.addEventListener("admin-participant:input-toggle", this.boundSyncDisabled)
    this.syncDisabled()
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseOnOutsideClick)
    this.element.removeEventListener("admin-participant:input-toggle", this.boundSyncDisabled)
  }

  toggle(event) {
    event.preventDefault()
    if (this.inputTarget.disabled) return

    this.open ? this.close() : this.openPanel()
  }

  openPanel() {
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.searchTarget.value = ""
    this.filter()
    requestAnimationFrame(() => this.searchTarget.focus())
  }

  close() {
    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.optionTargets.forEach((option) => {
      const visible = option.dataset.searchText.includes(query)
      option.hidden = !visible
      if (visible) visibleCount += 1
    })

    this.emptyTarget.hidden = visibleCount > 0
  }

  choose(event) {
    const option = event.currentTarget
    if (option.disabled) return

    this.inputTarget.value = option.dataset.value
    this.labelTarget.textContent = option.dataset.label

    this.optionTargets.forEach((target) => {
      target.setAttribute("aria-selected", target === option ? "true" : "false")
    })

    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
    this.buttonTarget.focus()
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      this.buttonTarget.focus()
    }
  }

  closeOnOutsideClick(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  syncDisabled() {
    this.buttonTarget.disabled = this.inputTarget.disabled
    this.buttonTarget.setAttribute("aria-disabled", this.inputTarget.disabled ? "true" : "false")

    if (this.inputTarget.disabled) this.close()
  }

  get open() {
    return !this.panelTarget.hidden
  }
}
