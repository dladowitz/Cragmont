import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "article", "body"]

  toggle(event) {
    const article = event.target.value === "article"
    for (const [fieldset, visible] of [[this.articleTarget, article], [this.linkTarget, !article]]) {
      fieldset.hidden = !visible
      fieldset.disabled = !visible
    }
  }

  // Same Markdown insertion as the trip report editor, without its autosave.
  format({ params: { marker } }) {
    const field = this.bodyTarget
    const selection = field.value.slice(field.selectionStart, field.selectionEnd) || "text"
    field.setRangeText(marker + selection + (marker.endsWith(" ") ? "" : marker), field.selectionStart, field.selectionEnd, "select")
    field.focus()
  }
}
