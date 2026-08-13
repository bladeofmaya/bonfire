import { Controller } from "@hotwired/stimulus"
import "lucide"

export default class extends Controller {
  connect() {
    globalThis.lucide?.createIcons({
      icons: { UserRoundPlus: globalThis.lucide.UserRoundPlus },
      root: this.element
    })
  }
}
