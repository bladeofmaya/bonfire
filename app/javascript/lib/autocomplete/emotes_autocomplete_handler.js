import BaseAutocompleteHandler from "lib/autocomplete/base_autocomplete_handler"
import { PUNCTUATION_PATTERN } from "lib/autocomplete/constants"

export default class extends BaseAutocompleteHandler {
  get pattern() {
    return new RegExp(`^:(.*?)(${PUNCTUATION_PATTERN.source}*)$`)
  }

  insertAutocompletable(emote, range, terminator) {
    const attachment = new Trix.Attachment({
      content: `<img class="custom-emote" src="${emote.avatar_url}" alt=":${emote.shortcode}:" title=":${emote.shortcode}:">`,
      contentType: "application/vnd.bonfire.emote",
      sgid: emote.sgid
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
