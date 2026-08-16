import { Controller } from "@hotwired/stimulus"
import "lucide"

export default class extends Controller {
  connect() {
    globalThis.lucide?.createIcons({
      icons: {
        GripVertical: globalThis.lucide.GripVertical,
        Maximize: globalThis.lucide.Maximize,
        Minimize: globalThis.lucide.Minimize,
        Pause: globalThis.lucide.Pause,
        PictureInPicture2: globalThis.lucide.PictureInPicture2,
        Play: globalThis.lucide.Play,
        RotateCcw: globalThis.lucide.RotateCcw,
        UserRoundPlus: globalThis.lucide.UserRoundPlus,
        Volume2: globalThis.lucide.Volume2,
        VolumeX: globalThis.lucide.VolumeX,
        X: globalThis.lucide.X
      },
      root: this.element
    })
  }
}
