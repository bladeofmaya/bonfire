import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"
import { ignoringBriefDisconnects } from "helpers/dom_helpers"

export default class extends Controller {
  static targets = [ "room" ]
  static classes = [ "unread", "current" ]

  #disconnected = true

  async connect() {
    this.channel ??= await cable.subscribeTo({ channel: "UnreadRoomsChannel" }, {
      connected: this.#channelConnected.bind(this),
      disconnected: this.#channelDisconnected.bind(this),
      received: this.#unread.bind(this)
    })
  }

  disconnect() {
    ignoringBriefDisconnects(this.element, () => {
      this.channel?.unsubscribe()
      this.channel = null
    })
  }

  loaded() {
    this.read({ detail: { roomId: Current.room.id } })
  }

  read({ detail: { roomId } }) {
    const room = this.#findRoomTarget(roomId)

    this.roomTargets.forEach(roomTarget => {
      roomTarget.classList.toggle(this.currentClass, roomTarget.dataset.roomId == roomId)
    })

    if (room) {
      room.classList.remove(this.unreadClass)
      this.#updateUnreadCount(room, 0)
      this.dispatch("read", { detail: { targetId: roomId } })
    }
  }

  #channelConnected() {
    if (this.#disconnected) {
      this.#disconnected = false
      this.element.reload()
    }
  }

  #channelDisconnected() {
    this.#disconnected = true
  }

  #unread({ roomId, unreadCount, unreadMentionCount }) {
    const unreadRoom = this.#findRoomTarget(roomId)

    if (unreadRoom) {
      if (Current.room.id != roomId) {
        unreadRoom.classList.add(this.unreadClass)
        const count = unreadRoom.classList.contains("direct") ? unreadCount : unreadMentionCount
        this.#updateUnreadCount(unreadRoom, count ?? this.#unreadCount(unreadRoom) + 1)
      }

      const sortableItem = unreadRoom.closest("[data-sorted-list-target='item']")
      this.dispatch("unread", { detail: { targetId: sortableItem?.id || unreadRoom.id } })
    }
  }

  #findRoomTarget(roomId) {
    return this.roomTargets.find(roomTarget => roomTarget.dataset.roomId == roomId)
  }

  #unreadCount(room) {
    return Number.parseInt(room.querySelector(".sidebar-unread-count")?.textContent || "0", 10)
  }

  #updateUnreadCount(room, count) {
    const badge = room.querySelector(".sidebar-unread-count")

    if (badge) {
      badge.textContent = count
      badge.hidden = count === 0
      const noun = badge.classList.contains("channel__mention-count") ? "mention" : "message"
      badge.setAttribute("aria-label", `${count} unread ${noun}${count === 1 ? "" : "s"}`)
    }
  }
}
