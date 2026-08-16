import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { expiresAt: String }

  connect() {
    const delay = new Date(this.expiresAtValue).getTime() - Date.now()
    if (delay <= 0) return this.element.remove()

    this.timer = setTimeout(() => this.element.remove(), delay)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
