import DOMPurify from "dompurify"

let diagramCount = 0

export async function drawMermaid(source, { maxWidth } = {}) {
  const { render } = await import("pele")
  await document.fonts.ready

  const { svg } = render(source, {
    maxWidth,
    fontFamily: getComputedStyle(document.body).fontFamily,
    idPrefix: `mermaid-diagram-${++diagramCount}-`,
    images: false
  })

  return sanitizeDiagramSvg(svg)
}

// The source is user-written and the SVG is built in the browser after the server's
// sanitizer has run. The SVG profile admits no HTML elements at all, so an HTML label that
// ever gets past Pele is dropped here instead of rendered.
export function sanitizeDiagramSvg(svg) {
  return DOMPurify.sanitize(svg, {
    ALLOW_DATA_ATTR: false,
    SAFE_FOR_XML: true,
    USE_PROFILES: { svg: true, svgFilters: true }
  })
}
