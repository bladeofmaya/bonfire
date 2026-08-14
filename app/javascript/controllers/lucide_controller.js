import { Controller } from "@hotwired/stimulus"
import "lucide"

export default class extends Controller {
  connect() {
    globalThis.lucide?.createIcons({
      icons: {
        GripVertical: globalThis.lucide.GripVertical,
        UserRoundPlus: globalThis.lucide.UserRoundPlus,
        X: globalThis.lucide.X
      },
      root: this.element
    })
  }
}
