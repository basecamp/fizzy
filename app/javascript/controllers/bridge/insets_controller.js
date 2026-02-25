import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Bridge component to control custom safe-area insets from native apps.
// Sets CSS variables --injected-safe-inset-(top|right|bottom|left).
export default class extends BridgeComponent {
  static component = "insets"

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
      this.#setInsets(message.data)
    })
  }

  #setInsets({ top, right, bottom, left }) {
    const root = document.documentElement.style
    root.setProperty("--injected-safe-inset-top", `${top}px`)
    root.setProperty("--injected-safe-inset-right", `${right}px`)
    root.setProperty("--injected-safe-inset-bottom", `${bottom}px`)
    root.setProperty("--injected-safe-inset-left", `${left}px`)
  }
}
