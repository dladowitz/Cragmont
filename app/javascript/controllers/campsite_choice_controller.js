import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chooser", "option", "panel"]

  connect() {
    if (this.hasChooserTarget) {
      this.hidePanels()
    } else {
      this.select()
    }
  }

  select() {
    if (!this.hasOptionTarget) return

    const selectedCampsiteId = this.optionTargets.find((option) => option.checked)?.value
    if (!selectedCampsiteId) return

    if (this.hasChooserTarget) {
      this.chooserTarget.hidden = true
    }

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.campsiteId !== selectedCampsiteId
    })
  }

  change() {
    if (this.hasChooserTarget) {
      this.chooserTarget.hidden = false
    }

    this.optionTargets.forEach((option) => {
      option.checked = false
    })
    this.hidePanels()
  }

  hidePanels() {
    this.panelTargets.forEach((panel) => {
      panel.hidden = true
    })
  }
}
