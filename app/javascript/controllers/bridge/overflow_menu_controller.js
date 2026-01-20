import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "overflow-menu"
  static targets = [ "item" ]

  itemTargetConnected() {
    this.notifyBridgeOfConnect()
  }

  itemTargetDisconnected() {
    if (!this.#isControllerTearingDown) {
      this.notifyBridgeOfConnect()
    }
  }

  notifyBridgeOfConnect() {
    const items = this.#enabledItemTargets
      .map((target, index) => {
        const element = new BridgeElement(target)
        return { title: element.title, index }
      })

    this.send("connect", { items }, message => {
      this.#clickItem(message)
    })
  }

  #clickItem(message) {
    const selectedIndex = message.data.selectedIndex
    this.#enabledItemTargets[selectedIndex].click()
  }

  get #enabledItemTargets() {
    return this.itemTargets
      .filter(target => !target.closest("[data-bridge-disabled]"))
  }

  #isControllerTearingDown() {
    return !document.body.contains(this.element)
  }
}
