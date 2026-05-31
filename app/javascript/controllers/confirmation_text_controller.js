import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]
  static values = { phrase: String }

  connect() {
    this.update()
  }

  update() {
    this.submitTarget.disabled = this.inputTarget.value !== this.phraseValue
  }
}
