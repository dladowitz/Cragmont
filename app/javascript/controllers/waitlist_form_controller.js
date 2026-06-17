import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "guestFields", "guestToggle", "minorFields", "minorToggle" ]

  connect() {
    this.togglePartyFields()
  }

  togglePartyFields() {
    if (this.hasMinorFieldsTarget && this.hasMinorToggleTarget) {
      this.toggleFieldGroup(this.minorFieldsTarget, this.minorToggleTarget.checked)
    }

    if (this.hasGuestFieldsTarget && this.hasGuestToggleTarget) {
      this.toggleFieldGroup(this.guestFieldsTarget, this.guestToggleTarget.checked)
    }
  }

  toggleFieldGroup(group, selected) {
    group.hidden = !selected
    const requiredDatasetKey = group.dataset.requiredDatasetKey
    const rows = Array.from(group.querySelectorAll("[data-party-row]"))

    rows.forEach((row, index) => {
      if (!selected) {
        row.hidden = index !== 0
        row.dataset.partyRowVisible = index === 0 ? "true" : "false"
      } else if (index === 0) {
        row.hidden = false
        row.dataset.partyRowVisible = "true"
      }

      const rowActive = selected && !row.hidden
      row.querySelectorAll("input").forEach((input) => {
        input.disabled = !rowActive
        input.required = rowActive && input.dataset[requiredDatasetKey] === "true"
        if (!rowActive) input.value = ""
      })
    })

    this.updateAddButton(group, selected)
  }

  revealPartyRow(event) {
    const group = event.currentTarget.closest("[data-party-fields]")
    if (!group) return

    const hiddenRow = Array.from(group.querySelectorAll("[data-party-row]"))
      .find((row) => row.hidden)
    if (!hiddenRow) return

    hiddenRow.hidden = false
    hiddenRow.dataset.partyRowVisible = "true"
    this.toggleFieldGroup(group, true)
  }

  removePartyRow(event) {
    const row = event.currentTarget.closest("[data-party-row]")
    const group = event.currentTarget.closest("[data-party-fields]")
    if (!row || !group) return

    const visibleRows = Array.from(group.querySelectorAll("[data-party-row]"))
      .filter((partyRow) => !partyRow.hidden)
    const firstRow = visibleRows[0]
    const removingOnlyVisibleRow = visibleRows.length === 1

    if (row === firstRow && removingOnlyVisibleRow) {
      this.setGroupToggle(group, false)
      this.toggleFieldGroup(group, false)
      return
    }

    if (row === firstRow) {
      this.copyRowValues(visibleRows[1], firstRow)
      this.clearRow(visibleRows[1])
      visibleRows[1].hidden = true
      visibleRows[1].dataset.partyRowVisible = "false"
    } else {
      this.clearRow(row)
      row.hidden = true
      row.dataset.partyRowVisible = "false"
    }

    this.toggleFieldGroup(group, true)
  }

  updateAddButton(group, selected) {
    const addButton = group.querySelector("[data-add-party-row]")
    if (!addButton) return

    const rows = Array.from(group.querySelectorAll("[data-party-row]"))
    addButton.hidden = !selected || rows.every((row) => !row.hidden)
  }

  setGroupToggle(group, checked) {
    if (group.dataset.partyFields === "guest") {
      this.guestToggleTarget.checked = checked
    } else if (group.dataset.partyFields === "minor") {
      this.minorToggleTarget.checked = checked
    }
  }

  copyRowValues(sourceRow, targetRow) {
    const sourceInputs = Array.from(sourceRow.querySelectorAll("input"))
    const targetInputs = Array.from(targetRow.querySelectorAll("input"))

    targetInputs.forEach((input, index) => {
      input.value = sourceInputs[index]?.value || ""
    })
  }

  clearRow(row) {
    row.querySelectorAll("input").forEach((input) => {
      input.value = ""
      input.required = false
    })
  }
}
