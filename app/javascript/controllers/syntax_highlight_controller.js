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
      const inline = await drawMermaid(source, { maxWidth: pre.clientWidth })
      const expanded = await drawMermaid(source)
      if (this.#stillMermaid(pre, source)) pre.replaceWith(this.#diagramWith(inline, expanded))
    } catch {
      pre.toggleAttribute("data-mermaid-failed", true)
    }
  }

  // A morph during the draw may have changed the block's source or language.
  #stillMermaid(pre, source) {
    return pre.isConnected && pre.dataset.language === "mermaid" && pre.textContent === source
  }

  #diagramWith(inline, expanded) {
    const diagram = document.getElementById("mermaid-diagram-template").content.firstElementChild.cloneNode(true)
    diagram.querySelector(".mermaid-diagram__inline").innerHTML = inline
    diagram.querySelector(".mermaid-diagram__expanded").innerHTML = expanded

    const { width, height } = diagram.querySelector(".mermaid-diagram__expanded svg").viewBox.baseVal
    diagram.style.setProperty("--diagram-width", width)
    diagram.style.setProperty("--diagram-height", height)

    return diagram
  }
}
