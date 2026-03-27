import { BridgeElement } from "@hotwired/hotwire-native-bridge"

BridgeElement.prototype.getButton = function() {
  return {
    title: this.title,
    icon: this.getIcon(),
    displayTitle: this.getDisplayTitle(),
    displayAsPrimaryAction: this.getDisplayAsPrimaryAction(),
    slot: this.getSlot()
  }
}

BridgeElement.prototype.getIcon = function() {
  const url = this.bridgeAttribute("icon-url")

  if (url) {
    return { url }
  }

  return null
}

BridgeElement.prototype.getDisplayTitle = function() {
  return !!this.bridgeAttribute("display-title")
}

BridgeElement.prototype.getDisplayAsPrimaryAction = function() {
  return !!this.bridgeAttribute("display-as-primary-action")
}

BridgeElement.prototype.getSlot = function () {
  return this.bridgeAttribute("slot") ?? "right"
}
