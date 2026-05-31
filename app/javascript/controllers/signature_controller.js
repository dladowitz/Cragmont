import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "acknowledgementInput",
    "arrivalDate",
    "canvas",
    "checkoutDate",
    "input",
    "intro",
    "minorFields",
    "signupKind",
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
    this.toggleMinorFields()
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

    if (this.minorSignupSelected() && !this.firstMinorRowComplete()) {
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

  toggleMinorFields() {
    if (!this.hasMinorFieldsTarget || !this.hasSignupKindTarget) return

    const selected = this.minorSignupSelected()
    this.minorFieldsTarget.hidden = !selected
    this.minorFieldsTarget.querySelectorAll("input").forEach((input) => {
      input.disabled = !selected
    })
    this.minorFieldsTarget.querySelectorAll("[data-required-for-minor='true']").forEach((input) => {
      input.required = selected
    })
  }

  minorSignupSelected() {
    if (!this.hasSignupKindTarget) return false

    return this.signupKindTargets.find((input) => input.checked)?.value === "with_minors"
  }

  firstMinorRowComplete() {
    if (!this.hasMinorFieldsTarget) return true

    return Array.from(this.minorFieldsTarget.querySelectorAll("[data-required-for-minor='true']"))
      .every((input) => input.checkValidity())
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
