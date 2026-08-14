import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      draggable: ".channel-order-item",
      handle: ".channel-order-item__handle",
      ghostClass: "channel-order-item--ghost",
      chosenClass: "channel-order-item--dragging",
      onEnd: () => this.#persist()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  moveWithKeyboard(event) {
    if (!event.key.match(/^Arrow(Up|Down)$/)) return

    event.preventDefault()
    const item = event.currentTarget.closest(".channel-order-item")
    const sibling = event.key === "ArrowUp" ? item.previousElementSibling : item.nextElementSibling
    if (!sibling) return

    if (event.key === "ArrowUp") {
      this.element.insertBefore(item, sibling)
    } else {
      this.element.insertBefore(sibling, item)
    }

    event.currentTarget.focus()
    this.#persist()
  }

  async #persist() {
    const items = [ ...this.element.querySelectorAll(".channel-order-item") ]
    const roomIds = items.map(item => item.dataset.sortedListId)
    const positions = items.map(item => Number(item.dataset.sortedListPosition)).sort((a, b) => a - b)
    const response = await patch(this.urlValue, {
      body: JSON.stringify({ room_ids: roomIds }),
      responseKind: "turbo-stream"
    })

    if (!response.ok) {
      document.getElementById("channel-order-status").textContent = "Channel order could not be updated."
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      items.forEach((item, index) => item.dataset.sortedListPosition = positions[index])
    }
  }
}
