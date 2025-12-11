import { Controller } from "@hotwired/stimulus"
import { FetchRequest } from "@rails/request.js"

// AI Assistant controller for rich text editor integration
// Provides writing assistance, file analysis, and research capabilities
export default class extends Controller {
  static targets = ["editor", "menu", "loading"]
  static values = {
    improveUrl: { type: String, default: "/ai/writing/improve" },
    summarizeUrl: { type: String, default: "/ai/writing/summarize" },
    expandUrl: { type: String, default: "/ai/writing/expand" },
    researchUrl: { type: String, default: "/ai/research/research" },
    breakDownUrl: { type: String, default: "/ai/research/break_down_task" }
  }

  connect() {
    // Look for editor in the parent form, or as a sibling, or in the document
    this.editor = this.hasEditorTarget ? this.editorTarget :
      this.element.parentElement?.querySelector("lexxy-editor") ||
      this.element.closest("form")?.querySelector("lexxy-editor") ||
      document.querySelector("lexxy-editor")
  }

  // Writing Assistant Actions
  async improve() {
    const text = this.getSelectedText() || this.getEditorContent()
    if (!text) return

    const result = await this.callAgent(this.improveUrlValue, { text })
    if (result) this.replaceContent(result.content)
  }

  async summarize() {
    const text = this.getSelectedText() || this.getEditorContent()
    if (!text) return

    const result = await this.callAgent(this.summarizeUrlValue, { text })
    if (result) this.insertAtCursor(result.content)
  }

  async expand() {
    const text = this.getSelectedText() || this.getEditorContent()
    if (!text) return

    const result = await this.callAgent(this.expandUrlValue, { text })
    if (result) this.replaceContent(result.content)
  }

  // Research Actions
  async research() {
    const text = this.getSelectedText() || this.getEditorContent()
    if (!text) return

    const result = await this.callAgent(this.researchUrlValue, { query: text })
    if (result) this.insertAtCursor("\n\n" + result.content)
  }

  async breakDown() {
    const text = this.getSelectedText() || this.getEditorContent()
    if (!text) return

    const result = await this.callAgent(this.breakDownUrlValue, { task: text })
    if (result) this.insertAtCursor("\n\n" + result.content)
  }

  // Helper Methods
  async callAgent(url, params) {
    this.showLoading()

    try {
      const request = new FetchRequest("POST", url, {
        body: JSON.stringify(params),
        contentType: "application/json",
        responseKind: "json"
      })

      const response = await request.perform()

      if (response.ok) {
        return await response.json
      } else {
        const error = await response.json
        console.error("AI Assistant error:", error)
        return null
      }
    } catch (error) {
      console.error("AI Assistant request failed:", error)
      return null
    } finally {
      this.hideLoading()
    }
  }

  getSelectedText() {
    if (this.editor && typeof this.editor.getSelectedText === "function") {
      return this.editor.getSelectedText()
    }

    const selection = window.getSelection()
    return selection.toString().trim()
  }

  getEditorContent() {
    if (this.editor) {
      if (typeof this.editor.getContent === "function") {
        return this.editor.getContent()
      }
      if (this.editor.value !== undefined) {
        return this.editor.value
      }
    }
    return ""
  }

  replaceContent(newContent) {
    const selection = window.getSelection()

    if (selection.rangeCount > 0 && !selection.isCollapsed) {
      const range = selection.getRangeAt(0)
      range.deleteContents()
      range.insertNode(document.createTextNode(newContent))
    } else if (this.editor) {
      if (typeof this.editor.setContent === "function") {
        this.editor.setContent(newContent)
      } else if (this.editor.value !== undefined) {
        this.editor.value = newContent
      }
    }

    this.dispatchChange()
  }

  insertAtCursor(content) {
    const selection = window.getSelection()

    if (selection.rangeCount > 0) {
      const range = selection.getRangeAt(0)
      range.collapse(false) // Move to end of selection
      range.insertNode(document.createTextNode(content))
      range.collapse(false)
    } else if (this.editor) {
      if (typeof this.editor.insertContent === "function") {
        this.editor.insertContent(content)
      } else if (this.editor.value !== undefined) {
        this.editor.value += content
      }
    }

    this.dispatchChange()
  }

  dispatchChange() {
    if (this.editor) {
      this.editor.dispatchEvent(new CustomEvent("lexxy:change", { bubbles: true }))
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
    this.element.classList.add("ai-loading")
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
    this.element.classList.remove("ai-loading")
  }

  toggleMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle("hidden")
    }
  }
}
