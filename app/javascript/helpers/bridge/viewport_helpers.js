let top = 0
const viewportTarget = window.visualViewport || window

export const viewport = {
  get top() {
    return top
  },
  get height() {
    return viewportTarget.height || window.innerHeight
  }
}

function update() {
  requestAnimationFrame(() => {
    const styles = getComputedStyle(document.documentElement)
    const customInset = styles.getPropertyValue("--custom-safe-inset-top")
    const fallbackInset = styles.getPropertyValue("--safe-area-inset-top")
    const insetValue = (customInset || fallbackInset).trim()
    top = parseInt(insetValue || "0", 10) || 0
  })
}

viewportTarget.addEventListener("resize", update)
update()
