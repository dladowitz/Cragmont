import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "minorFields", "signupKind" ]

  connect() {
    this.toggleMinorFields()
  }

  toggleMinorFields() {
    const selected = this.signupKindTargets.find((input) => input.checked)?.value === "with_minors"

    this.minorFieldsTarget.hidden = !selected
    this.minorFieldsTarget.querySelectorAll("input").forEach((input) => {
      input.disabled = !selected
      if (!selected) input.value = ""
    })
  }
}
