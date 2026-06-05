import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "existingFields",
    "newFields",
    "existingInput",
    "newInput",
    "option",
    "waiveOption",
    "waiveReasonFields",
    "waiveReasonSelect",
    "otherWaiveReasonField",
    "otherWaiveReasonInput"
  ]

  connect() {
    this.toggle()
  }

  toggle() {
    const useExistingAccount = this.selectedOptionValue === "existing"

    this.existingFieldsTarget.hidden = !useExistingAccount
    this.newFieldsTarget.hidden = useExistingAccount
    this.toggleInputs(this.existingInputTargets, useExistingAccount)
    this.toggleInputs(this.newInputTargets, !useExistingAccount)
    this.toggleWaivePaymentFields()
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

  toggleWaivePaymentFields() {
    if (!this.hasWaiveReasonFieldsTarget) return

    const waivePayment = this.selectedWaiveOptionValue === "1"
    const otherReason = this.hasWaiveReasonSelectTarget && this.waiveReasonSelectTarget.value === "other"

    this.waiveReasonFieldsTarget.hidden = !waivePayment
    this.waiveReasonSelectTarget.disabled = !waivePayment
    this.waiveReasonSelectTarget.required = waivePayment

    this.otherWaiveReasonFieldTarget.hidden = !waivePayment || !otherReason
    this.otherWaiveReasonInputTarget.disabled = !waivePayment || !otherReason
    this.otherWaiveReasonInputTarget.required = waivePayment && otherReason
  }

  get selectedWaiveOptionValue() {
    return this.waiveOptionTargets.find((option) => option.checked)?.value
  }
}
