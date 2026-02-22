import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "share"

  share() {
    const description = this.bridgeElement.bridgeAttribute("share-description")
    this.send("share", {
      title: document.title,
      url: window.location.href,
      description
    })
  }
}
