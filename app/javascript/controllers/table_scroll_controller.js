import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.tables = this.element.querySelectorAll("table")
    this.update = () => this.tables.forEach((table) => {
      table.classList.toggle("is-scrollable", table.scrollWidth > table.clientWidth + 1)
    })
    this.resizeObserver = new ResizeObserver(this.update)
    this.tables.forEach((table) => this.resizeObserver.observe(table))
    this.update()
  }

  disconnect() {
    this.resizeObserver.disconnect()
  }
}
