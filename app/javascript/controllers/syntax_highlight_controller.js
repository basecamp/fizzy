import { Controller } from "@hotwired/stimulus"
import { highlightCode } from "lexxy"

export default class extends Controller {
  connect() {
    highlightCode()
  }
}
