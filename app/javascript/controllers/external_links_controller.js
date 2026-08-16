import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.refresh()
  }

  disconnect() {
    cancelAnimationFrame(this.refreshFrame)
  }

  refresh() {
    this.updateLinks(this.element)
  }

  refreshAfterRender() {
    cancelAnimationFrame(this.refreshFrame)
    this.refreshFrame = requestAnimationFrame(() => this.refresh())
  }

  updateLinks(root) {
    if (root.matches?.("a[href]")) this.updateLink(root)
    root.querySelectorAll?.("a[href]").forEach((link) => this.updateLink(link))
  }

  updateLink(link) {
    const url = new URL(link.href, document.baseURI)
    if (![ "http:", "https:" ].includes(url.protocol) || url.origin === window.location.origin) return

    link.target = "_blank"
    link.relList.add("noopener", "noreferrer")
  }
}
