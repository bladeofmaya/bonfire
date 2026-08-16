import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { expiresAt: String }

  connect() {
    const delay = new Date(this.expiresAtValue).getTime() - Date.now()
    if (delay <= 0) return this.markOffline()

    this.timer = setTimeout(() => this.markOffline(), delay)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  markOffline() {
    this.element.textContent = "OFFLINE"
    this.element.classList.add("channel-live-badge--offline")
  }
}
