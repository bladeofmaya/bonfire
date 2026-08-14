import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog", "autofocus" ]

  connect() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
    if (this.hasAutofocusTarget) this.autofocusTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  clear() {
    this.element.closest("turbo-frame")?.replaceChildren()
  }
}
