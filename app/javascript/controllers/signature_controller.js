import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    availableParticipantCapacity: Number,
    showCapacityWarning: Boolean,
    uncountedMinorAgeLimit: Number
  }

  static targets = [
    "acknowledgementInput",
    "arrivalDate",
    "capacityWarning",
    "canvas",
    "checkoutDate",
    "guestFields",
    "guestToggle",
    "input",
    "intro",
    "minorFields",
    "minorToggle",
    "signupStep",
    "submit",
    "waiver",
    "waiverStep"
  ]

  connect() {
    this.canvasContext = this.canvasTarget.getContext("2d")
    this.drawing = false
    this.signed = false
    this.waiverRead = false
    this.boundStart = this.start.bind(this)
    this.boundDraw = this.draw.bind(this)
    this.boundStop = this.stop.bind(this)
    this.boundResize = this.resize.bind(this)
    this.canvasTarget.addEventListener("mousedown", this.boundStart)
    this.canvasTarget.addEventListener("mousemove", this.boundDraw)
    window.addEventListener("mouseup", this.boundStop)
    this.canvasTarget.addEventListener("touchstart", this.boundStart, { passive: false })
    this.canvasTarget.addEventListener("touchmove", this.boundDraw, { passive: false })
    window.addEventListener("touchend", this.boundStop)
    window.addEventListener("touchcancel", this.boundStop)
    this.resize()
    this.clear()
    this.togglePartyFields()
    this.updateCapacityWarning()
    this.checkWaiverScroll()
    window.addEventListener("resize", this.boundResize)
  }

  disconnect() {
    this.canvasTarget.removeEventListener("mousedown", this.boundStart)
    this.canvasTarget.removeEventListener("mousemove", this.boundDraw)
    window.removeEventListener("mouseup", this.boundStop)
    this.canvasTarget.removeEventListener("touchstart", this.boundStart)
    this.canvasTarget.removeEventListener("touchmove", this.boundDraw)
    window.removeEventListener("touchend", this.boundStop)
    window.removeEventListener("touchcancel", this.boundStop)
    window.removeEventListener("resize", this.boundResize)
  }

  resize() {
    const ratio = window.devicePixelRatio || 1
    const rect = this.canvasTarget.getBoundingClientRect()
    const width = rect.width || this.canvasTarget.width
    const height = rect.height || this.canvasTarget.height

    if (this.canvasWidth === width && this.canvasHeight === height && this.ratio === ratio) return

    this.canvasWidth = width
    this.canvasHeight = height
    this.ratio = ratio
    this.canvasTarget.width = width * ratio
    this.canvasTarget.height = height * ratio
    this.canvasContext.setTransform(ratio, 0, 0, ratio, 0, 0)
    this.canvasContext.lineCap = "round"
    this.canvasContext.lineJoin = "round"
    this.canvasContext.lineWidth = 3
    this.canvasContext.strokeStyle = "#1f2933"
    this.canvasContext.fillStyle = "#1f2933"

    if (this.signed) {
      this.signed = false
      this.update()
    }
  }

  start(event) {
    this.checkWaiverScroll()
    if (!this.waiverRead) return
    if (event.button !== undefined && event.button !== 0) return

    event.preventDefault()
    this.resize()
    this.drawing = true
    this.canvasContext.beginPath()
    const [x, y] = this.point(event)
    this.canvasContext.arc(x, y, this.canvasContext.lineWidth / 2, 0, Math.PI * 2)
    this.canvasContext.fill()
    this.canvasContext.beginPath()
    this.canvasContext.moveTo(x, y)
    this.signed = true
    this.update()
  }

  draw(event) {
    this.checkWaiverScroll()
    if (!this.waiverRead || !this.drawing) return

    event.preventDefault()
    this.canvasContext.lineTo(...this.point(event))
    this.canvasContext.stroke()
    this.signed = true
    this.update()
  }

  stop(event) {
    if (!this.drawing) return

    event.preventDefault()
    this.drawing = false
    this.update()
  }

  clear() {
    this.canvasContext.clearRect(0, 0, this.canvasTarget.width, this.canvasTarget.height)
    this.signed = false
    this.update()
  }

  showAcknowledgement() {
    this.checkAttendanceDates()
    if (!this.element.reportValidity()) return

    if (this.minorSignupSelected() && !this.requiredFieldsComplete(this.minorFieldsTarget, "requiredForMinor")) {
      this.element.reportValidity()
      return
    }

    if (this.guestSignupSelected() && !this.requiredFieldsComplete(this.guestFieldsTarget, "requiredForGuest")) {
      this.element.reportValidity()
      return
    }

    this.signupStepTarget.hidden = true
    this.introTarget.hidden = false
  }

  checkAttendanceDates() {
    if (!this.hasArrivalDateTarget || !this.hasCheckoutDateTarget) return true

    this.checkoutDateTarget.setCustomValidity("")
    if (!this.arrivalDateTarget.value || !this.checkoutDateTarget.value) return true
    if (this.arrivalDateTarget.value < this.checkoutDateTarget.value) return true

    this.checkoutDateTarget.setCustomValidity("Checkout date must be after the arrival date.")
    return false
  }

  showWaiver() {
    this.acknowledgementInputTarget.value ||= new Date().toISOString()
    this.introTarget.hidden = true
    this.waiverStepTarget.hidden = false
    this.resize()
    this.checkWaiverScroll()
  }

  checkWaiverScroll() {
    this.waiverRead = this.waiverScrolledToBottom()
    this.canvasTarget.classList.toggle("disabled", !this.waiverRead)
    this.update()
  }

  waiverScrolledToBottom() {
    const waiver = this.waiverTarget
    if (waiver.clientHeight === 0) return false

    return waiver.scrollTop + waiver.clientHeight >= waiver.scrollHeight - 2
  }

  update() {
    this.inputTarget.value = this.signed ? this.canvasTarget.toDataURL("image/png") : ""
    this.submitTarget.disabled = !this.waiverRead || !this.signed
  }

  togglePartyFields() {
    this.toggleFieldGroup(this.hasMinorFieldsTarget ? this.minorFieldsTarget : null, this.minorSignupSelected(), "requiredForMinor")
    this.toggleFieldGroup(this.hasGuestFieldsTarget ? this.guestFieldsTarget : null, this.guestSignupSelected(), "requiredForGuest")
    this.updateCapacityWarning()
  }

  minorSignupSelected() {
    if (!this.hasMinorToggleTarget) return false

    return this.minorToggleTarget.checked
  }

  guestSignupSelected() {
    if (!this.hasGuestToggleTarget) return false

    return this.guestToggleTarget.checked
  }

  toggleFieldGroup(group, selected, requiredDatasetKey) {
    if (!group) return

    group.hidden = !selected
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
    this.updateCapacityWarning()
  }

  requiredFieldsComplete(group, requiredDatasetKey) {
    if (!group) return true

    return Array.from(group.querySelectorAll(`[data-${this.kebabCase(requiredDatasetKey)}='true']`))
      .every((input) => input.checkValidity())
  }

  revealPartyRow(event) {
    const group = event.currentTarget.closest("[data-party-fields]")
    if (!group) return

    const hiddenRow = Array.from(group.querySelectorAll("[data-party-row]"))
      .find((row) => row.hidden)
    if (!hiddenRow) return

    hiddenRow.hidden = false
    hiddenRow.dataset.partyRowVisible = "true"
    this.toggleFieldGroup(group, true, group.dataset.requiredDatasetKey)
    this.updateCapacityWarning()
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
      this.toggleFieldGroup(group, false, group.dataset.requiredDatasetKey)
      this.updateCapacityWarning()
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

    this.toggleFieldGroup(group, true, group.dataset.requiredDatasetKey)
    this.updateCapacityWarning()
  }

  updateAddButton(group, selected) {
    const addButton = group.querySelector("[data-add-party-row]")
    if (!addButton) return

    const rows = Array.from(group.querySelectorAll("[data-party-row]"))
    addButton.hidden = !selected || rows.every((row) => !row.hidden)
  }

  setGroupToggle(group, checked) {
    if (group.dataset.partyFields === "guest" && this.hasGuestToggleTarget) {
      this.guestToggleTarget.checked = checked
    } else if (group.dataset.partyFields === "minor" && this.hasMinorToggleTarget) {
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
    })
  }

  updateCapacityWarning() {
    if (!this.hasCapacityWarningTarget || !this.showCapacityWarningValue) return

    this.capacityWarningTarget.hidden = this.partyCapacityCount() <= this.availableParticipantCapacityValue
  }

  partyCapacityCount() {
    return 1 + this.visibleAdultCount() + this.capacityCountedMinorCount()
  }

  visibleAdultCount() {
    if (!this.hasGuestFieldsTarget || this.guestFieldsTarget.hidden) return 0

    return Array.from(this.guestFieldsTarget.querySelectorAll("[data-party-row]"))
      .filter((row) => !row.hidden).length
  }

  capacityCountedMinorCount() {
    if (!this.hasMinorFieldsTarget || this.minorFieldsTarget.hidden) return 0

    return Array.from(this.minorFieldsTarget.querySelectorAll("[data-party-row]"))
      .filter((row) => !row.hidden)
      .filter((row) => {
        const age = Number.parseInt(row.querySelector("input[type='number']")?.value || "", 10)

        return Number.isInteger(age) && age >= this.uncountedMinorAgeLimitValue
      }).length
  }

  kebabCase(value) {
    return value.replace(/[A-Z]/g, (character) => `-${character.toLowerCase()}`)
  }

  point(event) {
    const rect = this.canvasTarget.getBoundingClientRect()
    const pointer = event.touches?.[0] || event

    return [
      pointer.clientX - rect.left,
      pointer.clientY - rect.top
    ]
  }
}
