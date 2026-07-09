import { Controller } from "@hotwired/stimulus"

// Tentative Firefox-only fix for the card title losing focus after pasting into
// the description editor.
//
// When files/images are pasted into Lexxy, the editor restores focus to itself
// one animation frame later (Lexxy's #preservingScrollPosition calls
// editor.focus() after an awaited frame). In Firefox the deferred refocus can
// land after the user has already moved to the title field and started typing,
// so every keystroke bounces focus back to the description editor.
//
// This guard wraps the editor's focus() and skips it while the title field is
// the intended focus target, so a stray deferred refocus can't steal focus.
export default class extends Controller {
  static targets = [ "title", "editor" ]
  static values = { guardMs: { type: Number, default: 150 } }

  connect() {
    this.blockUntil = 0
    this.originalFocus = this.editorTarget.focus.bind(this.editorTarget)
    this.editorTarget.focus = this.#guardedFocus.bind(this)
  }

  disconnect() {
    if (this.originalFocus) {
      this.editorTarget.focus = this.originalFocus
      this.originalFocus = null
    }
  }

  // Called when the title field gains focus or receives input. Opens a short
  // window during which the editor is not allowed to grab focus back, covering
  // the async gap where document.activeElement may briefly not be the title.
  arm() {
    this.blockUntil = performance.now() + this.guardMsValue
  }

  #guardedFocus(...args) {
    const titleFocused = document.activeElement === this.titleTarget
    const inGuardWindow = performance.now() < this.blockUntil

    if (titleFocused || inGuardWindow) return

    return this.originalFocus(...args)
  }
}
