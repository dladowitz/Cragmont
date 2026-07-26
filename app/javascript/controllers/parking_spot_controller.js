import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "status"]

  connect() {
    this.savedValue = this.selectTarget.value
  }

  async submit(event) {
    event.preventDefault()

    const form = event.currentTarget
    const select = this.selectTarget
    const formData = new FormData(form)

    this.setStatus("Saving...")
    select.disabled = true

    try {
      const response = await fetch(this.jsonUrl(form), {
        method: form.method || "post",
        body: formData,
        credentials: "same-origin",
        headers: {
          "Accept": "application/json, text/javascript, */*; q=0.01",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })
      const data = await this.responseJson(response)

      if (!response.ok) throw new Error(data.message || "Unable to update parking.")
      if (!data.assignment) throw new Error("Unable to update parking.")

      this.savedValue = data.assignment || select.value
      this.updateParkingCounts(data)
      this.setStatus("Saved")
      window.setTimeout(() => this.clearStatus("Saved"), 1600)
    } catch (error) {
      select.value = this.savedValue
      this.setStatus(error.message || "Try again")
    } finally {
      select.disabled = false
    }
  }

  updateParkingCounts(data) {
    const campsite = this.element.closest("[data-parking-campsite-id]")
    if (!campsite) return

    const assignedCount = campsite.querySelector("[data-parking-assigned-count]")
    const fcfsCount = campsite.querySelector("[data-parking-fcfs-count]")

    if (assignedCount && data.assigned_count !== undefined) {
      assignedCount.textContent = data.assigned_count
    }

    if (fcfsCount && data.first_come_first_serve_count !== undefined) {
      fcfsCount.textContent = data.first_come_first_serve_count
    }
  }

  jsonUrl(form) {
    const url = new URL(form.action)

    if (!url.pathname.endsWith(".json")) {
      url.pathname = `${url.pathname}.json`
    }

    return url.toString()
  }

  async responseJson(response) {
    const contentType = response.headers.get("content-type") || ""

    if (!contentType.includes("application/json")) {
      throw new Error("Unable to update parking. Refresh and try again.")
    }

    return response.json()
  }

  setStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
  }

  clearStatus(message) {
    if (!this.hasStatusTarget || this.statusTarget.textContent !== message) return

    this.statusTarget.textContent = ""
    this.statusTarget.hidden = true
  }
}
