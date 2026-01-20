import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "text-size"

  connect() {
    super.connect()
    this.notifyBridgeOfConnect()
  }

  disconnect() {
    super.disconnect()
    this.send("disconnect")
  }

  notifyBridgeOfConnect() {
    this.send("connect", {}, message => {
      this.#setTextSize(message.data)
    })
  }

  #setTextSize(data) {
    document.documentElement.dataset.textSize = data.textSize
  }
}
