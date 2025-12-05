import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

export default class extends Controller {
  static targets = [ "select" ]

  async loadUsers(event) {
    const accountId = event?.target?.value
    
    if (!accountId) {
      this.selectTarget.innerHTML = '<option value="">Select an account first…</option>'
      this.selectTarget.disabled = true
      return
    }

    this.selectTarget.disabled = true
    this.selectTarget.innerHTML = '<option value="">Loading users…</option>'

    try {
      const response = await get(`/admin/api_tokens/users_for_account?account_id=${accountId}`, {
        responseKind: "json"
      })

      if (response.ok) {
        const users = await response.json
        this.selectTarget.innerHTML = '<option value="">Select a user…</option>'
        
        users.forEach(user => {
          const option = document.createElement('option')
          option.value = user.id
          option.textContent = `${user.name} (${user.email})`
          this.selectTarget.appendChild(option)
        })
        
        this.selectTarget.disabled = false
      }
    } catch (error) {
      console.error("Error loading users:", error)
      this.selectTarget.innerHTML = '<option value="">Error loading users</option>'
    }
  }
}

