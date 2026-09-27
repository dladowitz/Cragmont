import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "group"]

  closeOutside(event) {
    this.groupTargets.forEach((group) => {
      if (!group.contains(event.target)) group.open = false
    })
    if (!this.element.contains(event.target)) this.toggleTarget.checked = false
  }

  closeOnEscape() {
    const group = this.groupTargets.find((group) => group.open)
    if (group) {
      group.open = false
      group.querySelector("summary").focus()
    } else if (this.toggleTarget.checked) {
      this.toggleTarget.checked = false
      this.toggleTarget.focus()
    }
  }
}
