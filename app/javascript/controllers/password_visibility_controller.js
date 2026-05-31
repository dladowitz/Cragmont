import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "showIcon", "hideIcon"]

  toggle() {
    const showingPassword = this.inputTarget.type === "text"

    this.inputTarget.type = showingPassword ? "password" : "text"
    this.showIconTarget.hidden = !showingPassword
    this.hideIconTarget.hidden = showingPassword
    this.button.setAttribute("aria-label", showingPassword ? "Show password" : "Hide password")
  }

  get button() {
    return this.element.querySelector(".password-visibility-toggle")
  }
}
