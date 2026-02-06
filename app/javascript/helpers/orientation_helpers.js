const EDGE_THRESHOLD = 16

export function orient({ target, anchor = null, reset = false }) {
  target.classList.remove("orient-left", "orient-right")
  target.style.removeProperty("--orient-offset")

  if (reset) return

  const targetGeometry = geometry(target)
  const anchorGeometry = geometry(anchor)
  const shouldOrientLeft = targetGeometry.spaceOnRight < EDGE_THRESHOLD && targetGeometry.spaceOnRight < targetGeometry.spaceOnLeft
  const shouldOrientRight = targetGeometry.spaceOnLeft < EDGE_THRESHOLD && targetGeometry.spaceOnLeft < targetGeometry.spaceOnRight

  if (shouldOrientLeft) {
    orientLeft({ el: target, targetGeometry, anchorGeometry })
  } else if (shouldOrientRight) {
    orientRight({ el: target, targetGeometry, anchorGeometry })
  }
}

function orientLeft({ el, targetGeometry, anchorGeometry }) {
  const offset = Math.min(0, anchorGeometry.spaceOnLeft + anchorGeometry.width - targetGeometry.width) * -1
  el.classList.add("orient-left")
  el.style.setProperty("--orient-offset", `${offset}px`)
}

function orientRight({ el, targetGeometry, anchorGeometry }) {
  const offset = Math.max(0, anchorGeometry.spaceOnLeft + targetGeometry.width - window.innerWidth) * -1
  el.classList.add("orient-right")
  el.style.setProperty("--orient-offset", `${offset}px`)
}

function geometry(el) {
  const rect = el.getBoundingClientRect()
  return {
    spaceOnLeft: rect.left,
    spaceOnRight: window.innerWidth - rect.right,
    width: rect.width
  }
}
