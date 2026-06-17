import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source", "preview" ]
  static values = { url: String }

  connect() {
    this.queuePreview()
  }

  queuePreview() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.preview(), 250)
  }

  async preview() {
    if (!this.hasUrlValue) return

    const body = new FormData()
    body.append("body", this.sourceTarget.value)

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body
    })

    if (response.ok) {
      this.previewTarget.innerHTML = await response.text()
    }
  }
}
