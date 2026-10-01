import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frequency", "fields", "endDate"]

  connect() {
    this.toggle()
  }

  toggle() {
    const repeating = this.frequencyTarget.value !== "none"
    this.fieldsTargets.forEach((field) => { field.hidden = !repeating })
    this.endDateTarget.required = repeating
  }
}
