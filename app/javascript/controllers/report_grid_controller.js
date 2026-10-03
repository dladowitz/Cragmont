import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.positions = new Map()
  }

  toggle(event) {
    const summary = event.target.closest(".club-report-details > summary")
    if (!summary) return
    event.preventDefault()

    const details = summary.parentElement
    const report = details.closest(".club-report")
    const previous = report.previousElementSibling
    const moveBeforeNeighbor = !details.open && previous && previous.offsetTop === report.offsetTop
    const reports = Array.from(this.element.children)
    const before = reports.map((card) => card.getBoundingClientRect())
    reports.forEach((card) => card.getAnimations().forEach((animation) => animation.cancel()))

    if (moveBeforeNeighbor) {
      const position = document.createComment("Report position before expansion")
      report.before(position)
      this.positions.set(report, position)
      previous.before(report)
    } else if (details.open && this.positions.has(report)) {
      this.positions.get(report).replaceWith(report)
      this.positions.delete(report)
    }
    details.open = !details.open
    summary.focus({ preventScroll: true })
    summary.scrollIntoView({ block: "nearest", behavior: "instant" })

    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return
    reports.forEach((card, index) => {
      const from = before[index]
      const to = card.getBoundingClientRect()
      card.animate([
        { transform: `translate(${from.left - to.left}px, ${from.top - to.top}px) scale(${from.width / to.width}, ${from.height / to.height})` },
        { transform: "none" }
      ], { duration: 280, easing: "ease-in-out" })
    })
  }

  reset() {
    this.positions.forEach((position, report) => position.replaceWith(report))
    this.positions.clear()
    this.element.querySelectorAll("details[open]").forEach((details) => { details.open = false })
  }
}
