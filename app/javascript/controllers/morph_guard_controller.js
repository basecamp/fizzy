import { Controller } from "@hotwired/stimulus"

// Marks the enclosing turbo-frame permanent while connected, so that a
// broadcasted page refresh can't morph away an edit in progress. The attribute
// is never in the server-rendered markup, so display mode stays morphable and
// page replacements never transplant the frame (https://github.com/basecamp/lexxy/issues/263).
export default class extends Controller {
  connect() {
    this.frame = this.element.closest("turbo-frame")
    this.frame?.setAttribute("data-turbo-permanent", "")
  }

  disconnect() {
    this.frame?.removeAttribute("data-turbo-permanent")
  }
}
