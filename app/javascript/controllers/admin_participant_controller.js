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
    "otherWaiveReasonInput",
    "campsiteOption",
    "campsiteChoiceRow"
  ]

  connect() {
    if (this.hasCampsiteOptionTarget) {
      this.toggleSelectedCampsite()
    } else if (this.hasOptionTarget) {
      this.toggle()
    } else {
      this.toggleWaivePaymentFields()
    }
  }

  toggle() {
    if (!this.hasOptionTarget) {
      this.toggleWaivePaymentFields()
      return
    }

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
      input.dispatchEvent(new CustomEvent("admin-participant:input-toggle", {
        bubbles: true,
        detail: { enabled }
      }))
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

  toggleSelectedCampsite() {
    if (!this.hasCampsiteOptionTarget) return

    const selectedCampsiteId = this.campsiteOptionTargets.find((option) => option.checked)?.value

    this.campsiteChoiceRowTargets.forEach((row) => {
      const selected = row.dataset.campsiteId === selectedCampsiteId
      row.classList.toggle("is-selected", selected)
      this.toggleWaitlistPaymentControls(row, selected)
    })
  }

  toggleWaitlistPaymentControls(row, selected) {
    const waiveOptions = Array.from(row.querySelectorAll("input[name='campsite_signup[waive_payment]']"))
    const reasonFields = row.querySelector(".admin-waitlist-waive-fields")
    const reasonSelect = row.querySelector("select[name='campsite_signup[waived_reason_type]']")
    const otherReasonField = row.querySelector(".admin-waitlist-other-waive-reason-field")
    const otherReasonInput = row.querySelector("textarea[name='campsite_signup[waived_reason]']")

    waiveOptions.forEach((option) => {
      option.disabled = !selected
      if (!selected) option.checked = false
    })

    if (selected && !waiveOptions.some((option) => option.checked)) {
      const noWaiverOption = waiveOptions.find((option) => option.value === "0")
      if (noWaiverOption) noWaiverOption.checked = true
    }

    const waivePayment = selected && waiveOptions.some((option) => option.checked && option.value === "1")
    const otherReason = waivePayment && reasonSelect?.value === "other"

    if (reasonFields) reasonFields.hidden = !waivePayment
    if (reasonSelect) {
      reasonSelect.disabled = !waivePayment
      reasonSelect.required = waivePayment
    }
    if (otherReasonField) otherReasonField.hidden = !otherReason
    if (otherReasonInput) {
      otherReasonInput.disabled = !otherReason
      otherReasonInput.required = otherReason
    }
  }
}
