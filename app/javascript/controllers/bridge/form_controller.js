import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "form"
  static targets = [ "submit" ]
  static values = { submitTitle: String }

  connect() {
    super.connect()

    if (this.hasSubmitTarget) {
      this.notifyBridgeOfConnect()
      this.observeSubmitTarget()
    }
  }

  disconnect() {
    super.disconnect()
    this.notifyBridgeOfDisonnect()
    this.submitObserver?.disconnect()
  }

  notifyBridgeOfConnect() {
    const element = new BridgeElement(this.submitTarget)
    const submitButton = { title: element.title }

    this.send("connect", { submitButton }, () => {
      this.submitTarget.click()
    })
  }

  notifyBridgeOfDisonnect() {
    this.send("disconnect")
  }

  observeSubmitTarget() {
    this.submitObserver = new MutationObserver(() => {
      this.send(this.submitTarget.disabled ? "submitDisabled" : "submitEnabled")
    })

    this.submitObserver.observe(this.submitTarget, {
      attributes: true,
      attributeFilter: [ "disabled" ]
    })
  }

  submitStart() {
    this.send("submitStart")
  }

  submitEnd() {
    this.send("submitEnd")
  }
}
