import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "stamp"
  static values = { scopeSelector: { type: String, default: "body" } }

  connect() {
    super.connect()

    if (this.element.closest(this.scopeSelectorValue)) {
      this.notifyBridgeOfConnect()
      this.#observeStamp()
    }
  }

  disconnect() {
    super.disconnect()
    this.notifyBridgeOfDisconnect()
    this.stampObserver?.disconnect()
  }

  notifyBridgeOfConnect() {
    const bridgeElement = this.bridgeElement

    this.send("connect", {
      title: bridgeElement.title,
      description: bridgeElement.bridgeAttribute("description")
    })
  }

  notifyBridgeOfDisconnect() {
    this.send("disconnect")
  }

  #observeStamp() {
    this.stampObserver = new MutationObserver(() => {
      this.notifyBridgeOfConnect()
    })

    this.stampObserver.observe(this.element, {
      attributes: true
    })
  }
}
