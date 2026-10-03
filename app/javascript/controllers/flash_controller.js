import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    this.resume()
  }

  disconnect() {
    this.pause()
    clearTimeout(this.removalTimer)
  }

  pause() {
    clearTimeout(this.timer)
  }

  resume() {
    this.pause()
    this.timer = setTimeout(() => {
      if (!this.element.matches(":hover, :focus-within")) this.dismiss()
    }, this.durationValue)
  }

  dismiss() {
    this.pause()
    this.element.classList.add("is-dismissing")
    this.removalTimer = setTimeout(() => this.element.remove(), 200)
  }
}
