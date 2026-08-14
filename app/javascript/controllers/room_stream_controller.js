import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

const SOURCE = "rtmp-homebrew"
const VERSION = 1
const STATES = {
  offline: "Stream is offline",
  connecting: "Connecting to stream…",
  live: "Stream is live",
  reconnecting: "Reconnecting to stream…",
  unauthorized: "Stream access is unavailable",
  error: "The stream could not be loaded"
}

export default class extends Controller {
  static targets = [ "frame", "status", "viewport", "poster" ]
  static values = { grantUrl: String, playerOrigin: String }

  connect() {
    this.ready = false
    this.stopped = false
    this.reconnectAttempts = 0
    this.receiveMessage = this.receiveMessage.bind(this)
    window.addEventListener("message", this.receiveMessage)
    this.setState("connecting")
  }

  disconnect() {
    this.teardown()
  }

  teardown() {
    this.stopped = true
    this.ready = false
    window.removeEventListener("message", this.receiveMessage)
    this.abortController?.abort()
    clearTimeout(this.refreshTimer)
    clearTimeout(this.reconnectTimer)
    this.token = null
  }

  visibilityChanged() {
    if (document.hidden) {
      clearTimeout(this.refreshTimer)
    } else if (this.ready && !this.stopped) {
      this.reconnectAttempts = 0
      this.authorize()
    }
  }

  receiveMessage(event) {
    if (event.origin !== this.playerOriginValue || event.source !== this.frameTarget.contentWindow) return
    const message = event.data
    if (!message || message.source !== SOURCE || message.version !== VERSION) return

    if (message.type === "player.ready") {
      this.ready = true
      this.stopped = false
      this.setState("connecting")
      this.authorize()
    } else if (message.type === "player.state" && Object.hasOwn(STATES, message.state)) {
      this.setState(message.state)
      if (message.state === "live") {
        this.reconnectAttempts = 0
        clearTimeout(this.reconnectTimer)
      }
      if ([ "offline", "reconnecting", "error" ].includes(message.state)) this.scheduleReconnect()
      if (message.state === "unauthorized") this.stopAuthorization()
    } else if (message.type === "token.refresh_requested") {
      this.authorize()
    }
  }

  async authorize() {
    if (!this.ready || this.stopped || document.hidden) return
    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const response = await post(this.grantUrlValue, {
        responseKind: "json",
        signal: this.abortController.signal
      })

      if ([ 401, 403, 404 ].includes(response.statusCode)) return this.stopAuthorization()
      if (!response.ok) return this.scheduleReconnect()

      const grant = await response.json
      if (grant.player_origin !== this.playerOriginValue) return this.stopAuthorization()

      this.token = grant.token
      this.frameTarget.contentWindow.postMessage({
        source: "bonfire",
        version: VERSION,
        type: "playback.authorize",
        token: this.token,
        expires_at: grant.expires_at,
        stream_path: grant.stream_path
      }, this.playerOriginValue)
      this.token = null
      this.scheduleRefresh()
    } catch (error) {
      if (error.name !== "AbortError") this.scheduleReconnect()
    }
  }

  setState(state) {
    this.viewportTarget.dataset.state = state
    this.statusTarget.textContent = STATES[state]
    if (this.hasPosterTarget) this.posterTarget.hidden = state === "live"
  }

  stopAuthorization() {
    this.stopped = true
    this.token = null
    this.abortController?.abort()
    clearTimeout(this.refreshTimer)
    clearTimeout(this.reconnectTimer)
    this.setState("unauthorized")
  }

  scheduleRefresh() {
    clearTimeout(this.refreshTimer)
    const jitter = Math.floor(Math.random() * 6001) - 3000
    this.refreshTimer = setTimeout(() => this.authorize(), 30_000 + jitter)
  }

  scheduleReconnect() {
    if (this.stopped || this.reconnectAttempts >= 5) return
    clearTimeout(this.refreshTimer)
    clearTimeout(this.reconnectTimer)
    const delay = Math.min(1000 * (2 ** this.reconnectAttempts++), 30_000)
    this.reconnectTimer = setTimeout(() => this.authorize(), delay)
  }
}
