import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "form"
  static targets = [ "submit", "cancel" ]
  static values = { submitTitle: String }

  submitTargetConnected() {
    this.notifyBridgeOfConnect()
    this.#observeSubmitTarget()
  }

  submitTargetDisconnected() {
    this.notifyBridgeOfDisonnect()
    this.submitObserver?.disconnect()
  }

  notifyBridgeOfConnect() {
    const submitElement = new BridgeElement(this.submitTarget)
    const cancelElement = this.hasCancelTarget ? new BridgeElement(this.cancelTarget) : null

    const submitButton = { title: submitElement.title }
    const cancelButton = cancelElement ? { title: cancelElement.title } : null

    this.send("connect", { submitButton, cancelButton }, message => this.receive(message))
  }

  receive(message) {
    switch (message.event) {
      case "submit":
        this.submitTarget.click()
        break
      case "cancel":
        this.cancelTarget.click()
        break
    }
  }

  notifyBridgeOfDisonnect() {
    this.send("disconnect")
  }

  submitStart() {
    this.send("submitStart")
  }

  submitEnd() {
    this.send("submitEnd")
  }

  #observeSubmitTarget() {
    this.submitObserver = new MutationObserver(() => {
      this.send(this.submitTarget.disabled ? "submitDisabled" : "submitEnabled")
    })

    this.submitObserver.observe(this.submitTarget, {
      attributes: true,
      attributeFilter: [ "disabled" ]
    })
  }
}
