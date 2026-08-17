import { Controller } from "@hotwired/stimulus"
import MentionsAutocompleteHandler from "lib/autocomplete/mentions_autocomplete_handler"
import ChannelsAutocompleteHandler from "lib/autocomplete/channels_autocomplete_handler"
import EmotesAutocompleteHandler from "lib/autocomplete/emotes_autocomplete_handler"
import { debounce } from "helpers/timing_helpers"

export default class extends Controller {
  static values = { url: String, roomsUrl: String, emotesUrl: String }

  initialize() {
    this.handlers = []
    this.search = debounce(this.search.bind(this), 300)
  }

  connect() {
    if (this.element == document.activeElement) {
      this.#installHandlers()
    }
  }

  focus(event) {
    this.#installHandlers()
  }

  search(event) {
    const content = this.editor.getDocument().toString()
    const position = this.editor.getPosition()
    this.handlers.forEach(handler => handler.updateWithContentAndPosition(content, position))
  }

  blur(event) {
    this.#uninstallHandlers()
  }

  #installHandlers() {
    this.#uninstallHandlers()
    this.handlers = [ new MentionsAutocompleteHandler(this.element, this.urlValue) ]
    if (this.hasRoomsUrlValue) this.handlers.push(new ChannelsAutocompleteHandler(this.element, this.roomsUrlValue))
    if (this.hasEmotesUrlValue) this.handlers.push(new EmotesAutocompleteHandler(this.element, this.emotesUrlValue))
  }

  #uninstallHandlers() {
    this.handlers.forEach(handler => handler.destroy())
    this.handlers = []
  }

  get editor() {
    return this.element.editor
  }
}
