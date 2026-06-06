import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async send(event) {
    event.preventDefault()

    const form = event.currentTarget
    const button = form.querySelector("button[type='submit'], input[type='submit']")
    const originalText = button?.textContent

    if (button) {
      button.disabled = true
      button.textContent = "Sending..."
    }

    try {
      const response = await fetch(form.action, {
        method: form.method,
        body: new FormData(form),
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })

      const data = await response.json()

      if (!response.ok) throw new Error(data.message || "Email failed")

      if (button) button.textContent = data.button_text || "Email sent"
    } catch {
      if (button) button.textContent = "Email failed"
    } finally {
      if (button) {
        window.setTimeout(() => {
          button.disabled = false
          button.textContent = originalText
        }, 2000)
      }
    }
  }
}
