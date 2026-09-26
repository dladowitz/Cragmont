import { Controller } from "@hotwired/stimulus"

const overflows = (element) => element && element.scrollWidth > element.clientWidth + 1

export default class extends Controller {
  connect() {
    this.tables = this.element.querySelectorAll("table")
    // Some tables keep a min-width and scroll inside a .table-wrapper instead of themselves.
    this.update = () => this.tables.forEach((table) => {
      table.classList.toggle("is-scrollable", overflows(table) || overflows(table.closest(".table-wrapper")))
    })
    this.resizeObserver = new ResizeObserver(this.update)
    this.tables.forEach((table) => {
      this.resizeObserver.observe(table)
      const wrapper = table.closest(".table-wrapper")
      if (wrapper) this.resizeObserver.observe(wrapper)
    })
    this.update()
  }

  disconnect() {
    this.resizeObserver.disconnect()
  }
}
