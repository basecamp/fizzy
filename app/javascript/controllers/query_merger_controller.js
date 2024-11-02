import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  merge({ params: { key, value } }) {
    const url = new URL(window.location.href)
    url.searchParams.set(key, value)
    Turbo.visit(url)
  }
}
