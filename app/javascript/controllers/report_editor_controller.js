import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "status", "publication", "photos", "previewContent", "writeTab", "previewTab", "publishButton", "hideButton"]
  static values = { id: Number, version: Number }

  connect() {
    this.pending = Promise.resolve()
    this.generation = 0
    this.savedGeneration = 0
    this.blocked = false
    this.beforeVisit = event => {
      if (this.dirty && !window.confirm("Your latest changes are not saved. Leave this page?")) event.preventDefault()
    }
    document.addEventListener("turbo:before-visit", this.beforeVisit)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
  }

  get dirty() { return this.generation !== this.savedGeneration }
  get endpoint() { return `/admin/trip_reports/${this.idValue}` }

  changed(event) {
    if (event?.target.type === "file") return // uploadCover saves the file itself.
    this.generation++
    this.statusTarget.textContent = "Unsaved changes"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.enqueue(() => this.save()), 1000)
  }

  enqueue(task) {
    this.pending = this.pending.then(async () => {
      if (this.blocked) throw new Error("Saving stopped to protect your changes. Open the latest report in another tab to resolve the conflict.")
      await task()
    }).catch(error => {
      this.statusTarget.textContent = error.message || "Couldn’t save. Your changes are still in this editor; try Save draft again."
      this.statusTarget.setAttribute("role", "alert")
    })
    return this.pending
  }

  reportData() {
    const report = {}
    for (const [name, value] of new FormData(this.formTarget)) {
      const match = name.match(/^trip_report\[([a-z_]+)\]$/)
      if (match) report[match[1]] = value
    }
    report.lock_version = this.versionValue
    if (this.hasPhotosTarget) report.photos = [...this.photosTarget.children].map(row => ({ id: Number(row.dataset.photoId), caption: row.querySelector("[data-caption]").value }))
    return report
  }

  async request(url, method, body) {
    const multipart = body instanceof FormData
    const response = await fetch(url, {
      method, credentials: "same-origin",
      headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content, ...(multipart ? {} : { "Content-Type": "application/json" }) },
      body: multipart ? body : JSON.stringify(body)
    })
    let result
    try { result = await response.json() } catch { throw new Error("Couldn’t save. Check your connection or sign in again in another tab; your text is still here.") }
    if (!response.ok) {
      if (response.status === 409) this.blocked = true
      throw new Error(result.error || result.message || "Couldn’t save. Try again.")
    }
    this.idValue = result.report.id
    this.versionValue = result.report.lock_version
    this.formTarget.querySelector("[name='trip_report[lock_version]']").value = this.versionValue
    this.formTarget.action = this.endpoint
    this.hideButtonTarget.hidden = false
    this.publicationTarget.textContent = result.report.status
    this.publishButtonTarget.textContent = result.report.published_at ? "Publish changes" : "Publish report"
    this.previewContentTarget.innerHTML = result.preview_html
    this.previewContentTarget.querySelector("details")?.setAttribute("open", "")
    // Replace the create URL after the first save so refreshing resumes this draft.
    if (!window.location.pathname.includes(`/${this.idValue}/edit`)) history.replaceState({}, "", result.report.edit_path)
    return result
  }

  async save() {
    if (!this.formTarget.checkValidity()) throw new Error("Complete the required title and dates to save your draft.")
    const generation = this.generation
    this.statusTarget.setAttribute("role", "status")
    this.statusTarget.textContent = "Saving…"
    await this.request(this.idValue ? this.endpoint : "/admin/trip_reports", this.idValue ? "PATCH" : "POST", { trip_report: this.reportData() })
    this.savedGeneration = generation
    this.statusTarget.textContent = this.dirty ? "New changes waiting to save…" : `Saved at ${new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}`
  }

  submit(event) {
    event.preventDefault()
    clearTimeout(this.timer)
    const publish = event.submitter?.value === "publish"
    this.enqueue(async () => {
      await this.save()
      if (publish) {
        const result = await this.request(`${this.endpoint}/publish`, "PATCH", { lock_version: this.versionValue })
        window.location.assign(result.report.public_path)
      }
    })
  }

  hide() {
    if (!window.confirm("Hide this entire report from visitors? It will stay hidden until you publish it again.")) return
    this.enqueue(async () => {
      await this.save()
      await this.request(`${this.endpoint}/hide`, "PATCH", { lock_version: this.versionValue })
      this.statusTarget.textContent = "Report hidden. Automatic publication will not restore it."
    })
  }

  uploadCover(event) {
    const input = event.target
    const file = input.files[0]
    if (!file) return
    clearTimeout(this.timer)
    this.enqueue(async () => {
      if (this.dirty || !this.idValue) await this.save()
      this.statusTarget.setAttribute("role", "status")
      this.statusTarget.textContent = "Uploading cover photo…"
      const body = new FormData()
      body.append("photo", file)
      body.append("lock_version", this.versionValue)
      const result = await this.request(`${this.endpoint}/cover_photo`, "POST", body)
      this.photosTarget.innerHTML = result.photos_html
      this.statusTarget.textContent = "On belay! Cover photo added. Publish to show it on Trip Reports."
    }).finally(() => { input.value = "" })
  }

  up(event) {
    const row = event.target.closest(".report-edit-photo")
    if (row.previousElementSibling) row.previousElementSibling.before(row)
    this.photosChanged()
  }
  down(event) {
    const row = event.target.closest(".report-edit-photo")
    if (row.nextElementSibling) row.nextElementSibling.after(row)
    this.photosChanged()
  }
  cover(event) { this.photosTarget.prepend(event.target.closest(".report-edit-photo")); this.photosChanged() }
  remove(event) { event.target.closest(".report-edit-photo").remove(); this.photosChanged() }

  photosChanged() { this.refreshPhotoControls(); this.changed() }

  refreshPhotoControls() {
    const rows = [...this.photosTarget.children]
    rows.forEach((row, index) => {
      const [cover, up, down, remove] = row.querySelectorAll("button")
      cover.textContent = index === 0 ? "Cover photo" : "Make cover"
      cover.setAttribute("aria-label", `Make photo ${index + 1} the cover`)
      up.setAttribute("aria-label", `Move photo ${index + 1} earlier`)
      down.setAttribute("aria-label", `Move photo ${index + 1} later`)
      remove.setAttribute("aria-label", `Remove photo ${index + 1} from draft`)
    })
  }

  format(event) {
    const field = this.formTarget.querySelector("textarea")
    const marker = event.target.dataset.marker
    const selection = field.value.slice(field.selectionStart, field.selectionEnd) || "text"
    field.setRangeText(marker + selection + (marker.endsWith(" ") ? "" : marker), field.selectionStart, field.selectionEnd, "select")
    field.focus()
    this.changed()
  }
  writeTab() { this.tab(false) }
  previewTab() {
    clearTimeout(this.timer)
    this.enqueue(async () => {
      if (this.dirty || !this.idValue) await this.save()
      this.tab(true)
    })
  }
  tab(preview) {
    this.element.classList.toggle("show-preview", preview)
    this.writeTabTarget.setAttribute("aria-pressed", String(!preview))
    this.previewTabTarget.setAttribute("aria-pressed", String(preview))
  }
  beforeLeave(event) { if (this.dirty) { event.preventDefault(); event.returnValue = "" } }
}
