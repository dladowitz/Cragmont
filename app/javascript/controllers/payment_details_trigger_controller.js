import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { paymentId: Number }

  open(event) {
    event.preventDefault()
    const trigger = document.querySelector(`[data-payment-details-payment-id="${this.paymentIdValue}"]`)
    trigger?.click()
  }
}
