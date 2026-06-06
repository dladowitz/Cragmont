import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  async copy(event) {
    event.preventDefault()
    if (!this.urlValue) return

    try {
      if (navigator.clipboard) {
        await navigator.clipboard.writeText(this.urlValue)
      } else {
        this.copyWithTextarea(this.urlValue)
      }
      this.showCopied(event.currentTarget)
    } catch {
      this.copyWithTextarea(this.urlValue)
      this.showCopied(event.currentTarget)
    }
  }

  copyWithTextarea(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.setAttribute("readonly", "")
    textarea.style.position = "absolute"
    textarea.style.left = "-9999px"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    textarea.remove()
  }

  showCopied(button) {
    button.classList.add("is-copied")
    button.setAttribute("aria-label", "Copied")

    setTimeout(() => {
      button.classList.remove("is-copied")
      button.removeAttribute("aria-label")
    }, 2000)
  }
}
