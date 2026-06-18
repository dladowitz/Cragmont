import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!window.location.hash.startsWith("#transaction-payment-")) return

    const row = this.element.querySelector(window.location.hash)
    const trigger = row?.querySelector("button[data-action~='modal#open']")
    if (!trigger) return

    requestAnimationFrame(() => trigger.click())
  }
}
