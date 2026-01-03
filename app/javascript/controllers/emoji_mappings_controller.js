import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "hiddenField"]

  connect() {
    console.log('emoji-mappings controller connected')
    this.updateMappings()
  }

  selectTargetConnected() {
    console.log('select target connected')
  }

  updateMappings() {
    const mappings = {}

    this.selectTargets.forEach(select => {
      const emoji = select.dataset.emoji
      const value = select.value

      console.log(`Emoji: ${emoji}, Value: ${value}`)

      if (value) {
        if (value.startsWith('move_to_column_')) {
          const columnId = value.replace('move_to_column_', '')
          mappings[emoji] = {
            action: 'move_to_column',
            column_id: columnId
          }
        } else {
          mappings[emoji] = {
            action: value
          }
        }
      }
    })

    const json = JSON.stringify(mappings)
    this.hiddenFieldTarget.value = json
    console.log('Updated emoji_action_mappings to:', json)
  }
}
