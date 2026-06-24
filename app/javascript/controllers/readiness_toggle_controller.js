import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async submit(event) {
    event.preventDefault()

    const form = event.currentTarget
    const button = form.querySelector("input[type='submit'], button[type='submit']")
    const originalLabel = this.buttonLabel(button)

    this.setButtonLabel(button, "Saving...")
    if (button) button.disabled = true

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

      if (!response.ok) throw new Error(data.message || "Unable to update readiness task.")

      this.updateTask(data.task)
      this.updateCount("overall", data.total)
      this.updateCount(data.category.key, data.category)
    } catch {
      this.setButtonLabel(button, "Try again")
      window.setTimeout(() => this.setButtonLabel(button, originalLabel), 2000)
    } finally {
      if (button) button.disabled = false
    }
  }

  updateTask(task) {
    const taskElement = document.querySelector(`[data-readiness-task-key="${CSS.escape(task.key)}"]`)
    if (!taskElement) return

    taskElement.classList.toggle("is-complete", task.complete)

    const status = taskElement.querySelector(".trip-readiness-task-status")
    if (status) status.innerHTML = task.complete ? this.doneStatusHtml() : this.openStatusHtml()

    const completedInput = taskElement.querySelector("input[name='completed']")
    if (completedInput) completedInput.value = task.completed_value

    const submitButton = taskElement.querySelector(".trip-readiness-toggle-form input[type='submit'], .trip-readiness-toggle-form button[type='submit']")
    this.setButtonLabel(submitButton, task.button_text)
  }

  updateCount(key, count) {
    const element = document.querySelector(`[data-readiness-count-key="${CSS.escape(key)}"]`)
    if (!element) return

    element.textContent = count.count_text
    element.classList.toggle("success-status", count.complete)
    element.classList.toggle("warning-status", !count.complete)
  }

  buttonLabel(button) {
    if (!button) return ""

    return button.value !== undefined ? button.value : button.textContent
  }

  setButtonLabel(button, label) {
    if (!button) return

    if (button.value !== undefined) {
      button.value = label
    } else {
      button.textContent = label
    }
  }

  doneStatusHtml() {
    return `
      <span class="trip-readiness-checkmark">
        <span class="trip-readiness-checkmark-icon" aria-hidden="true">&#10003;</span>
        <span>Done</span>
      </span>
    `
  }

  openStatusHtml() {
    return `<span class="trip-readiness-open-circle"></span>`
  }
}
