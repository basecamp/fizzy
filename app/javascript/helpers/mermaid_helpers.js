import DOMPurify from "dompurify"
import { getMetaContent } from "helpers/meta_helpers"

// Diagram source can set Mermaid options with a %%{init}%% directive. Mermaid ignores
// directives for the options listed in `secure`, so these stay as set here. Without
// htmlLabels and flowchart in the list, a directive turns HTML labels back on and
// user-written class and data-* attributes reach the page after the server's sanitizer.
// Without fontFamily and altFontFamily, a directive puts CSS of its own into the SVG's
// <style>: Mermaid only checks those for balanced braces.
const LOCKED_OPTIONS = [ "secure", "securityLevel", "startOnLoad", "maxTextSize", "suppressErrorRendering", "maxEdges", "htmlLabels", "flowchart", "themeCSS", "fontFamily", "altFontFamily" ]

let drawingFrame = null
let mermaidLoading = null
let drawing = Promise.resolve()
let diagramCount = 0

// Each diagram is drawn at the width it will be shown at, which Gantt charts read from the
// frame, so one diagram is drawn at a time.
export function drawMermaid(source, width) {
  const drawn = drawing.then(() => draw(source, width))
  drawing = drawn.catch(() => {})

  return drawn
}

async function draw(source, width) {
  const mermaid = await loadMermaid()
  drawingFrame.style.width = `${width}px`
  // A directive that fails to apply, such as a malformed theme colour, stays in Mermaid's
  // directive list and makes every later initialize throw. Only a render or a reset clears it.
  mermaid.mermaidAPI.reset()
  mermaid.initialize({ startOnLoad: false, securityLevel: "strict", secure: LOCKED_OPTIONS, suppressErrorRendering: true, htmlLabels: false, look: "classic", sequence: { wrap: true }, ...fizzyTheme() })

  const { svg } = await mermaid.render(`mermaid-diagram-${++diagramCount}`, source)
  return sanitizeDiagramSvg(svg)
}

// The source is user-written and the SVG is built in the browser after the server's
// sanitizer has run. The SVG profile admits no HTML elements at all, so an HTML label that
// gets past the locked options is dropped here instead of rendered.
export function sanitizeDiagramSvg(svg) {
  return DOMPurify.sanitize(svg, {
    ALLOW_DATA_ATTR: false,
    SAFE_FOR_XML: true,
    USE_PROFILES: { svg: true, svgFilters: true }
  })
}

// Mermaid measures every label by adding it to the document and reading its size, and each
// measurement recalculates styles and layout for the whole page. Mermaid runs in a hidden
// iframe instead, whose document holds nothing but the diagram being drawn.
function loadMermaid() {
  if (!drawingFrame?.isConnected) {
    drawingFrame = createDrawingFrame()
    mermaidLoading = loadMermaidInto(drawingFrame)
  }

  return mermaidLoading
}

// A page refresh morphs the body, which would remove the frame and the Mermaid loaded in it.
function createDrawingFrame() {
  const frame = document.createElement("iframe")
  frame.setAttribute("aria-hidden", "true")
  frame.setAttribute("data-turbo-permanent", "")
  frame.tabIndex = -1
  frame.style.cssText = "position: fixed; top: 0; left: -10000px; height: 0; border: 0; visibility: hidden"
  document.body.appendChild(frame)

  return frame
}

async function loadMermaidInto(frame) {
  await loadStylesheetsInto(frame)
  await loadFontsInto(frame)

  return new Promise((resolve, reject) => {
    const script = frame.contentDocument.createElement("script")
    script.src = getMetaContent("mermaid-script-url")
    script.onload = () => resolve(frame.contentWindow.mermaid)
    script.onerror = reject
    frame.contentDocument.head.appendChild(script)
  })
}

// The page's stylesheets bring its @font-face rules, so the frame measures labels in the
// same fonts. Firefox refuses FontFace objects from another document.
function loadStylesheetsInto(frame) {
  const stylesheets = [ ...document.head.querySelectorAll("link[rel=stylesheet]") ].map(link => new Promise(resolve => {
    const stylesheet = frame.contentDocument.createElement("link")
    stylesheet.rel = "stylesheet"
    stylesheet.href = link.href
    stylesheet.onload = stylesheet.onerror = resolve
    frame.contentDocument.head.appendChild(stylesheet)
  }))

  return Promise.all(stylesheets)
}

async function loadFontsInto(frame) {
  await document.fonts.ready

  const loadedFonts = [ ...document.fonts ].filter(font => font.status === "loaded")
  await Promise.all(loadedFonts.map(font => frame.contentDocument.fonts.load(`${font.style} ${font.weight} 16px "${font.family.replaceAll("\"", "")}"`)))
}

function fizzyTheme() {
  const styles = getComputedStyle(document.documentElement)
  const color = name => toRgb(styles.getPropertyValue(`--color-${name}`))
  const fontFamily = getComputedStyle(document.body).fontFamily

  return {
    theme: "base",
    fontFamily,
    themeVariables: {
      darkMode: isDarkMode(),
      fontFamily,
      background: color("canvas"),
      primaryColor: color("canvas"),
      primaryBorderColor: color("ink-light"),
      primaryTextColor: color("ink"),
      secondaryColor: color("selected-light"),
      tertiaryColor: color("canvas"),
      lineColor: color("ink-medium"),
      textColor: color("ink"),
      edgeLabelBackground: color("canvas"),
      actorBkg: color("canvas"),
      actorBorder: color("ink-light"),
      actorTextColor: color("ink"),
      signalColor: color("ink-medium"),
      signalTextColor: color("ink"),
      noteBkgColor: color("selected-light"),
      noteBorderColor: color("selected"),
      noteTextColor: color("ink")
    }
  }
}

// Mermaid derives shades from the theme colours and only parses hex, rgb and hsl, but
// Fizzy's colours are oklch. A canvas converts them.
function toRgb(color) {
  const context = document.createElement("canvas").getContext("2d", { willReadFrequently: true })
  context.fillStyle = color
  context.fillRect(0, 0, 1, 1)

  const [ red, green, blue ] = context.getImageData(0, 0, 1, 1).data
  return `rgb(${red}, ${green}, ${blue})`
}

function isDarkMode() {
  const theme = document.documentElement.dataset.theme

  if (theme === "dark" || theme === "light") {
    return theme === "dark"
  } else {
    return matchMedia("(prefers-color-scheme: dark)").matches
  }
}
