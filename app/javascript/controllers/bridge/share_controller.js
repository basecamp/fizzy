import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "share"

  shareUrl() {
    const description = this.bridgeElement.bridgeAttribute("share-description")
    this.send("shareUrl", {
      title: document.title,
      url: window.location.href,
      description: description
    })
  }
}
