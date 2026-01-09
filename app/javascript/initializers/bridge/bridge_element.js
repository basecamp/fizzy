import { BridgeElement } from "@hotwired/hotwire-native-bridge"

BridgeElement.prototype.getButton = function() {
  return {
    title: this.title,
    icon: this.getIcon()
  }
}

BridgeElement.prototype.getIcon = function() {
  const url = this.bridgeAttribute(`icon-url`)

  if (url) {
    return { url }
  }

  return null
}
