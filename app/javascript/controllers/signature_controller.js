import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "input", "submit"]

  connect() {
    this.canvasContext = this.canvasTarget.getContext("2d")
    this.drawing = false
    this.signed = false
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
    if (!this.drawing) return

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

  update() {
    this.inputTarget.value = this.signed ? this.canvasTarget.toDataURL("image/png") : ""
    this.submitTarget.disabled = !this.signed
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
