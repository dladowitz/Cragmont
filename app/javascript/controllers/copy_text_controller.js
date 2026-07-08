import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]
  static values = { text: String }

  async copy(event) {
    event.preventDefault()

    const text = this.copyText
    if (!text) return

    try {
      if (navigator.clipboard) {
        await navigator.clipboard.writeText(text)
      } else {
        this.copyWithTextarea(text)
      }
      this.showCopied(event.currentTarget)
    } catch {
      this.copyWithTextarea(text)
      this.showCopied(event.currentTarget)
    }
  }

  get copyText() {
    if (this.hasSourceTarget) {
      return this.sourceTarget.value || this.sourceTarget.textContent.trim()
    }

    return this.hasTextValue ? this.textValue : ""
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
    clearTimeout(this.copiedTimeout)
    button.classList.add("is-copied")
    button.setAttribute("aria-label", "Copied")

    this.copiedTimeout = setTimeout(() => {
      button.classList.remove("is-copied")
      button.removeAttribute("aria-label")
    }, 2000)
  }
}
