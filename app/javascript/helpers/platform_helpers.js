export function isTouchDevice() {
  return "ontouchstart" in window && navigator.maxTouchPoints > 0
}

export function isIos() {
  return /iPhone|iPad/.test(navigator.userAgent)
}

export function isAndroid() {
  return /Android/.test(navigator.userAgent)
}

export function isMobile() {
  return isIos() || isAndroid()
}
