import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { debounce } from "helpers/timing_helpers"

// Streams that re-render a column (card hotkeys, column edits and moves) don't
// know the board's filter, so they'd bring back unfiltered counts and frames.
// Once they've rendered, refresh the board from its own, filtered, URL.
export default class extends Controller {
  initialize() {
    this.debouncedRefresh = debounce(this.#refresh.bind(this), 50)
  }

  refreshAfterColumnStream(event) {
    if (this.#rendersColumns(event.target)) {
      const render = event.detail.render

      event.detail.render = async (streamElement) => {
        await render(streamElement)
        this.debouncedRefresh()
      }
    }
  }

  #rendersColumns(streamElement) {
    return streamElement.targetElements?.some(element => this.element.contains(element))
  }

  #refresh() {
    Turbo.session.refresh(document.baseURI)
  }
}
