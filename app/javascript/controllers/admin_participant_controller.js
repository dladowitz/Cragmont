import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["existingFields", "newFields", "existingInput", "newInput", "option"]

  connect() {
    this.toggle()
  }

  toggle() {
    const useExistingAccount = this.selectedOptionValue === "existing"

    this.existingFieldsTarget.hidden = !useExistingAccount
    this.newFieldsTarget.hidden = useExistingAccount
    this.toggleInputs(this.existingInputTargets, useExistingAccount)
    this.toggleInputs(this.newInputTargets, !useExistingAccount)
  }

  get selectedOptionValue() {
    return this.optionTargets.find((option) => option.checked)?.value
  }

  toggleInputs(inputs, enabled) {
    inputs.forEach((input) => {
      input.disabled = !enabled
      input.required = enabled && input.dataset.required === "true"
    })
  }
}
