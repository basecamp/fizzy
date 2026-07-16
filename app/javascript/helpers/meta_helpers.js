export function getMetaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.getAttribute("content")
}
