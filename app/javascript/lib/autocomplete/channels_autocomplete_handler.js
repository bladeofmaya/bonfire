import BaseAutocompleteHandler from "lib/autocomplete/base_autocomplete_handler"
import { PUNCTUATION_PATTERN } from "lib/autocomplete/constants"

export default class extends BaseAutocompleteHandler {
  get pattern() {
    return new RegExp(`^#(.*?)(${PUNCTUATION_PATTERN.source}*)$`)
  }

  insertAutocompletable(autocompletable, range, terminator) {
    const attachment = new Trix.Attachment({
      content: `<a class="channel-reference" href="${autocompletable.url}" data-turbo-frame="_top" sgid="${autocompletable.sgid}">${autocompletable.name}</a>`,
      contentType: "application/vnd.bonfire.channel",
      sgid: autocompletable.sgid
    })

    if (range) this.editor.setSelectedRange(range)
    this.editor.insertAttachment(attachment)
    this.editor.insertString(terminator)
  }

  getOffsetsAtPosition(position) {
    return this.editor.getClientRectAtPosition(position) || {}
  }

  get editor() {
    return this.element.editor
  }
}
