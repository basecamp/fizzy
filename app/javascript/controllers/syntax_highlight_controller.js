import { Controller } from "@hotwired/stimulus"
import { highlightCode } from "lexxy"
import { drawMermaid } from "helpers/mermaid_helpers"

export default class extends Controller {
  connect() {
    this.highlight()
  }

  highlight() {
    highlightCode()
    this.element.querySelectorAll("pre[data-language=mermaid]").forEach(pre => this.#drawDiagram(pre))
  }

  async #drawDiagram(pre) {
    const source = pre.textContent

    try {
      const svg = await drawMermaid(source, pre.clientWidth)
      if (this.#stillMermaid(pre, source)) pre.replaceWith(this.#diagramWith(svg))
    } catch {
      pre.toggleAttribute("data-mermaid-failed", true)
    }
  }

  // A morph during the draw may have changed the block's source or language.
  #stillMermaid(pre, source) {
    return pre.isConnected && pre.dataset.language === "mermaid" && pre.textContent === source
  }

  #diagramWith(svg) {
    const diagram = document.getElementById("mermaid-diagram-template").content.firstElementChild.cloneNode(true)
    diagram.querySelector(".mermaid-diagram__inline").innerHTML = svg
    diagram.querySelector(".mermaid-diagram__expanded").innerHTML = svg

    return diagram
  }
}
