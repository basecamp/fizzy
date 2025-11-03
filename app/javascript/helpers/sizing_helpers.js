export function limitHeightToViewport(el, sizing = true, margin = 64) {
  if (!el) return

  if (sizing) {
    const rect = el.getBoundingClientRect()
    const top = Math.max(rect.top, margin)
    const max = Math.max(0, window.innerHeight - margin - top)
    el.style.maxHeight = `${max}px`
  } else {
    el.style.maxHeight = ""
  }
}