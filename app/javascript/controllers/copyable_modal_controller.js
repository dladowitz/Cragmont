import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "source"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  async copy(event) {
    const text = this.sourceTarget.href || this.sourceTarget.textContent.trim()

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
