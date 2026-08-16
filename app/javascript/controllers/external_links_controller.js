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
    const href = link.getAttribute("href")
    if (!href) return

    let url
    try {
      url = new URL(href, document.baseURI)
    } catch (_error) {
      return
    }

    if (![ "http:", "https:" ].includes(url.protocol) || url.origin === window.location.origin) return

    link.target = "_blank"
    link.relList.add("noopener", "noreferrer")
  }
}
