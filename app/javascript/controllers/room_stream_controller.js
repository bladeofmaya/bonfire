import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

const SOURCE = "rtmp-homebrew"
const VERSION = 1
const VOLUME_KEY = "bonfire-stream-volume"
const STATES = {
  offline: "Stream is offline",
  connecting: "Connecting to stream…",
  live: "Stream is live",
  reconnecting: "Reconnecting to stream…",
  unauthorized: "Stream access is unavailable",
  error: "The stream could not be loaded"
}

export default class extends Controller {
  static targets = [ "frame", "player", "soundButton", "status", "viewport", "poster" ]
  static values = { grantUrl: String, playerOrigin: String, mediaUrl: String, direct: Boolean }

  connect() {
    this.ready = false
    this.stopped = false
    this.sourceLoaded = false
    this.reconnectAttempts = 0
    this.authorizationSequence = 0
    this.receiveMessage = this.receiveMessage.bind(this)
    this.setState("connecting")

    if (this.directValue) this.connectDirectPlayer()
    else window.addEventListener("message", this.receiveMessage)
  }

  async connectDirectPlayer() {
    try {
      const [ , hlsModule ] = await Promise.all([ import("vidstack"), import("hls.js") ])
      if (this.stopped) return

      this.Hls = hlsModule.default
      this.ready = true
      this.restoreVolume()
      await this.authorize()
    } catch (_error) {
      if (!this.stopped) this.setState("error")
    }
  }

  disconnect() {
    this.teardown()
  }

  teardown() {
    this.stopped = true
    this.ready = false
    this.authorizationSequence += 1
    window.removeEventListener("message", this.receiveMessage)
    this.abortController?.abort()
    clearTimeout(this.refreshTimer)
    clearTimeout(this.reconnectTimer)

    if (this.hasPlayerTarget) {
      this.playerTarget.pause?.()
      this.playerTarget.provider?.destroy?.()
      this.playerTarget.src = ""
    }

    this.token = null
    this.Hls = null
  }

  visibilityChanged() {
    if (document.hidden) {
      clearTimeout(this.refreshTimer)
      clearTimeout(this.reconnectTimer)
      if (this.hasPlayerTarget) this.playerTarget.provider?.instance?.stopLoad?.()
    } else if (this.ready && !this.stopped) {
      this.reconnectAttempts = 0
      this.authorize()
    }
  }

  receiveMessage(event) {
    if (!this.hasFrameTarget || event.origin !== this.playerOriginValue || event.source !== this.frameTarget.contentWindow) return
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

  configureProvider(event) {
    const provider = event.detail
    if (!this.directValue || provider?.type !== "hls" || !this.Hls) return

    provider.library = this.Hls
    provider.config = {
      lowLatencyMode: true,
      backBufferLength: 30,
      liveSyncDurationCount: 2,
      liveMaxLatencyDurationCount: 5,
      xhrSetup: xhr => {
        xhr.withCredentials = false
        if (this.token) xhr.setRequestHeader("Authorization", `Bearer ${this.token}`)
      }
    }
  }

  async authorize() {
    if (!this.ready || this.stopped || document.hidden) return
    const sequence = ++this.authorizationSequence
    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const response = await post(this.grantUrlValue, {
        responseKind: "json",
        signal: this.abortController.signal
      })
      if (sequence !== this.authorizationSequence || this.stopped) return

      if ([ 401, 403, 404 ].includes(response.statusCode)) return this.stopAuthorization()
      if (!response.ok) return this.scheduleReconnect()

      const grant = await response.json
      if (sequence !== this.authorizationSequence || this.stopped) return
      if (grant.player_origin !== this.playerOriginValue) return this.stopAuthorization()

      if (this.directValue) this.authorizeDirectPlayer(grant)
      else this.authorizeEmbeddedPlayer(grant)
      this.scheduleRefresh(grant.expires_at)
    } catch (error) {
      if (error.name !== "AbortError") this.scheduleReconnect()
    }
  }

  authorizeDirectPlayer(grant) {
    this.token = grant.token
    if (!this.sourceLoaded) {
      this.sourceLoaded = true
      this.playerTarget.src = { src: this.mediaUrlValue, type: "application/vnd.apple.mpegurl" }
    } else {
      this.playerTarget.provider?.instance?.startLoad?.()
    }
  }

  authorizeEmbeddedPlayer(grant) {
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
  }

  playing() {
    this.reconnectAttempts = 0
    clearTimeout(this.reconnectTimer)
    this.setState("live")
  }

  waiting() {
    if (this.viewportTarget.dataset.state === "live") this.setState("reconnecting")
  }

  error() {
    this.setState("error")
    this.scheduleReconnect()
  }

  hlsError(event) {
    if (!event.detail?.fatal) return
    this.setState(event.detail?.response?.code === 404 ? "offline" : "reconnecting")
    this.scheduleReconnect()
  }

  async watchWithSound() {
    if (!this.hasPlayerTarget) return
    this.playerTarget.muted = false
    if (this.playerTarget.volume === 0) this.playerTarget.volume = 1

    try {
      await this.playerTarget.play()
      this.soundButtonTarget.hidden = true
      this.persistVolume()
    } catch (_error) {
      this.playerTarget.muted = true
    }
  }

  volumeChanged() {
    if (this.hasPlayerTarget && !this.playerTarget.muted) this.persistVolume()
  }

  setVolume(event) {
    if (!this.hasPlayerTarget) return
    this.playerTarget.volume = Number.parseFloat(event.currentTarget.value)
    this.playerTarget.muted = this.playerTarget.volume === 0
    this.persistVolume()
  }

  restoreVolume() {
    if (!this.hasPlayerTarget) return
    const volume = Number.parseFloat(localStorage.getItem(VOLUME_KEY))
    if (Number.isFinite(volume)) this.playerTarget.volume = Math.min(1, Math.max(0, volume))
    this.playerTarget.muted = true
  }

  persistVolume() {
    try { localStorage.setItem(VOLUME_KEY, this.playerTarget.volume.toString()) } catch (_error) {}
  }

  setState(state) {
    this.viewportTarget.dataset.state = state
    const badgeState = [ "live", "offline" ].includes(state)
    this.statusTarget.classList.toggle("channel-live-badge", badgeState)
    this.statusTarget.classList.toggle("channel-live-badge--offline", state === "offline")
    this.statusTarget.textContent = state === "live" ? "LIVE" : state === "offline" ? "OFFLINE" : STATES[state]
    if (this.hasPosterTarget) this.posterTarget.hidden = state === "live"
  }

  stopAuthorization() {
    this.stopped = true
    this.authorizationSequence += 1
    this.token = null
    this.abortController?.abort()
    clearTimeout(this.refreshTimer)
    clearTimeout(this.reconnectTimer)
    if (this.hasPlayerTarget) {
      this.playerTarget.pause?.()
      this.playerTarget.provider?.instance?.stopLoad?.()
    }
    this.setState("unauthorized")
  }

  scheduleRefresh(expiresAt) {
    clearTimeout(this.refreshTimer)
    const expiresIn = new Date(expiresAt).getTime() - Date.now()
    const jitter = Math.floor(Math.random() * 6001) - 3000
    const delay = Math.max(5_000, Math.min(30_000 + jitter, expiresIn - 20_000))
    this.refreshTimer = setTimeout(() => this.authorize(), delay)
  }

  scheduleReconnect() {
    if (this.stopped || this.reconnectAttempts >= 5) return
    clearTimeout(this.refreshTimer)
    clearTimeout(this.reconnectTimer)
    const delay = Math.min(1000 * (2 ** this.reconnectAttempts++), 30_000)
    this.reconnectTimer = setTimeout(() => this.authorize(), delay)
  }
}
