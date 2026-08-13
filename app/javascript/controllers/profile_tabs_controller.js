import { Controller } from "@hotwired/stimulus"
import "lucide"

export default class extends Controller {
  static targets = [ "tab", "panel" ]
  static values = { defaultTab: { type: String, default: "profile" } }

  connect() {
    this.select(this.tabFromLocation || this.defaultTabValue, { updateLocation: false, focus: false })
    this.renderIcons()
  }

  change({ currentTarget }) {
    this.select(currentTarget.dataset.profileTabsName, { updateLocation: true, focus: false })
  }

  navigate(event) {
    const keys = [ "ArrowDown", "ArrowRight", "ArrowUp", "ArrowLeft", "Home", "End" ]
    if (!keys.includes(event.key)) return

    event.preventDefault()
    const currentIndex = this.tabTargets.indexOf(event.currentTarget)
    const nextIndex = this.nextIndex(event.key, currentIndex)
    const nextTab = this.tabTargets[nextIndex]

    this.select(nextTab.dataset.profileTabsName, { updateLocation: true, focus: true })
  }

  select(name, { updateLocation, focus }) {
    const selectedTab = this.tabTargets.find(tab => tab.dataset.profileTabsName === name) || this.tabTargets[0]
    if (!selectedTab) return

    this.tabTargets.forEach(tab => {
      const selected = tab === selectedTab
      tab.setAttribute("aria-selected", selected.toString())
      tab.tabIndex = selected ? 0 : -1
    })

    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.profileTabsName !== selectedTab.dataset.profileTabsName
    })

    if (updateLocation) history.replaceState(null, "", `#${selectedTab.dataset.profileTabsName}`)
    if (focus) selectedTab.focus()
  }

  renderIcons() {
    globalThis.lucide?.createIcons({
      icons: {
        UserRound: globalThis.lucide.UserRound,
        Palette: globalThis.lucide.Palette,
        MessagesSquare: globalThis.lucide.MessagesSquare,
        MonitorSmartphone: globalThis.lucide.MonitorSmartphone,
        Settings: globalThis.lucide.Settings,
        UsersRound: globalThis.lucide.UsersRound
      },
      root: this.element
    })
  }

  get tabFromLocation() {
    return window.location.hash.slice(1)
  }

  nextIndex(key, currentIndex) {
    if (key === "Home") return 0
    if (key === "End") return this.tabTargets.length - 1
    if ([ "ArrowDown", "ArrowRight" ].includes(key)) return (currentIndex + 1) % this.tabTargets.length
    return (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length
  }
}
