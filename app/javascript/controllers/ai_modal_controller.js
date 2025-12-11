import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

/**
 * AI Modal Controller
 *
 * Provides a modal interface for streaming AI interactions in Fizzy.
 * Shows real-time streaming content and allows users to apply, copy, or discard results.
 */
export default class extends Controller {
  static targets = ["dialog", "content", "status", "applyButton", "copyButton"]
  static values = {
    action: String,
    originalContent: String,
    hasSelection: Boolean
  }

  connect() {
    console.log('[AI Modal] Controller connected')
    this.cable = window.App || (window.App = {})
    if (!this.cable.cable) {
      this.cable.cable = createConsumer()
    }
    this.subscription = null
    this.accumulatedContent = ''
    this.isStreaming = false
    this.storedSelection = null
    this.storedFullContent = null

    // Listen for global AI action events (from toolbar buttons outside controller scope)
    this.handleGlobalAiAction = this.handleGlobalAiAction.bind(this)
    document.addEventListener('ai-modal:perform', this.handleGlobalAiAction)

    // Track content changes when user edits
    this.handleContentInput = this.handleContentInput.bind(this)
    if (this.hasContentTarget) {
      this.contentTarget.addEventListener('input', this.handleContentInput)
    }
  }

  disconnect() {
    document.removeEventListener('ai-modal:perform', this.handleGlobalAiAction)
    if (this.hasContentTarget) {
      this.contentTarget.removeEventListener('input', this.handleContentInput)
    }
    this.cleanup()
  }

  handleContentInput() {
    this.accumulatedContent = this.contentTarget.innerText
  }

  /**
   * Handle AI action triggered from anywhere on the page
   */
  handleGlobalAiAction(event) {
    const { actionType } = event.detail
    console.log('[AI Modal] Global action received:', actionType)

    const editor = this.getEditor()
    if (!editor) {
      console.error('[AI Modal] Editor not found')
      return
    }

    const fullContent = this.getEditorContent(editor)
    const selection = this.getEditorSelection(editor)

    if (!fullContent || !fullContent.trim()) {
      alert('Please add some content to the editor first')
      return
    }

    // Store for gsub-style replacement on apply
    this.storedSelection = selection
    this.storedFullContent = fullContent
    this.originalContentValue = fullContent
    this.actionValue = actionType
    this.hasSelectionValue = !!selection

    this.openModal(actionType, selection ? 'selection' : '')
    this.startStreaming(actionType, selection, fullContent)
  }

  /**
   * Open the modal and start an AI action
   * Called via data-action="ai-modal#perform"
   */
  perform(event) {
    event.preventDefault()

    const button = event.currentTarget
    const actionType = button.dataset.aiAction
    const editor = this.getEditor()

    if (!editor) {
      console.error('[AI Modal] Editor not found')
      return
    }

    const fullContent = this.getEditorContent(editor)
    const selection = this.getEditorSelection(editor)

    if (!fullContent || !fullContent.trim()) {
      alert('Please add some content to the editor first')
      return
    }

    // Store for gsub-style replacement on apply
    this.storedSelection = selection
    this.storedFullContent = fullContent
    this.originalContentValue = fullContent
    this.actionValue = actionType
    this.hasSelectionValue = !!selection

    this.openModal(actionType, selection ? 'selection' : '')
    this.startStreaming(actionType, selection, fullContent)
  }

  openModal(actionType, context = '') {
    // Reset state
    this.accumulatedContent = ''
    this.isStreaming = true

    // Update UI
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = ''
      this.contentTarget.contentEditable = 'false'
    }
    this.setStatus(this.getActionLabel(actionType), true)
    if (this.hasApplyButtonTarget) this.applyButtonTarget.disabled = true
    if (this.hasCopyButtonTarget) this.copyButtonTarget.disabled = true

    // Show modal
    if (this.hasDialogTarget) {
      this.dialogTarget.showModal()
    }
  }

  closeModal() {
    this.cleanup()
    if (this.hasDialogTarget) {
      this.dialogTarget.close()
    }
  }

  async startStreaming(actionType, selection, fullContent) {
    try {
      // Build request body
      const requestBody = {
        action_type: actionType,
        full_content: fullContent,
        stream: true
      }

      if (selection) {
        requestBody.selection = selection
      }

      // Map action type to endpoint
      const endpoint = this.getEndpointForAction(actionType)

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify(requestBody)
      })

      const data = await response.json()

      if (data.error) {
        this.showError(data.error)
        return
      }

      // Small delay to ensure subscription is ready
      await new Promise(resolve => setTimeout(resolve, 100))

      this.subscribeToStream(data.stream_id)
    } catch (error) {
      console.error('[AI Modal] Request error:', error)
      this.showError('Failed to start AI processing')
    }
  }

  getEndpointForAction(actionType) {
    const endpoints = {
      improve: '/ai/writing/stream',
      summarize: '/ai/writing/stream',
      expand: '/ai/writing/stream',
      adjust_tone: '/ai/writing/stream',
      research: '/ai/research/research',
      suggest_topics: '/ai/research/suggest_topics',
      break_down_task: '/ai/research/break_down_task'
    }
    return endpoints[actionType] || '/ai/writing/stream'
  }

  subscribeToStream(streamId) {
    console.log('[AI Modal] Subscribing to stream:', streamId)

    this.subscription = this.cable.cable.subscriptions.create(
      { channel: "AssistantStreamChannel", stream_id: streamId },
      {
        connected: () => {
          console.log('[AI Modal] Connected to stream')
        },
        disconnected: () => {
          console.log('[AI Modal] Disconnected from stream')
        },
        received: (message) => {
          this.handleStreamMessage(message)
        }
      }
    )
  }

  handleStreamMessage(message) {
    console.log('[AI Modal] Message received:', message)

    if (message.tool_status) {
      this.setStatus(message.tool_status.description, true)
    } else if (message.content) {
      this.accumulatedContent += message.content
      if (this.hasContentTarget) {
        this.contentTarget.innerHTML = this.renderMarkdown(this.accumulatedContent)
        this.contentTarget.scrollTop = this.contentTarget.scrollHeight
      }
    } else if (message.done) {
      this.onStreamComplete()
    } else if (message.error) {
      this.showError(message.error)
    }
  }

  onStreamComplete() {
    console.log('[AI Modal] Stream complete')
    this.isStreaming = false
    this.setStatus('Complete', false)
    if (this.hasApplyButtonTarget) this.applyButtonTarget.disabled = false
    if (this.hasCopyButtonTarget) this.copyButtonTarget.disabled = false

    if (this.hasContentTarget) {
      this.contentTarget.contentEditable = 'true'
    }

    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  /**
   * Apply the generated content to the editor
   */
  apply() {
    const editor = this.getEditor()
    if (!editor || !this.accumulatedContent) return

    // Clean up any markdown code fences
    let cleanContent = this.accumulatedContent.trim()
    if (cleanContent.startsWith('```')) {
      cleanContent = cleanContent.replace(/^```\w*\n?/, '').replace(/\n?```$/, '')
    }

    let finalContent
    if (this.storedSelection && this.hasSelectionValue) {
      finalContent = this.storedFullContent.replace(this.storedSelection, cleanContent)
    } else {
      finalContent = cleanContent
    }

    // Update editor based on type
    if (editor.tagName === 'LEXXY-EDITOR') {
      if (typeof editor.setContent === 'function') {
        editor.setContent(finalContent)
      }
    } else if (editor.tagName === 'TEXTAREA') {
      editor.value = finalContent
    } else if (editor.tagName === 'TRIX-EDITOR') {
      editor.editor.loadHTML(finalContent)
    }

    editor.dispatchEvent(new Event('input', { bubbles: true }))
    this.closeModal()
  }

  async copy() {
    if (!this.accumulatedContent) return

    try {
      await navigator.clipboard.writeText(this.accumulatedContent)

      if (this.hasCopyButtonTarget) {
        const originalText = this.copyButtonTarget.textContent
        this.copyButtonTarget.textContent = 'Copied!'
        setTimeout(() => {
          this.copyButtonTarget.textContent = originalText
        }, 1500)
      }
    } catch (error) {
      console.error('[AI Modal] Copy failed:', error)
    }
  }

  discard() {
    this.closeModal()
  }

  showError(message) {
    this.isStreaming = false
    this.setStatus('Error', false)
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = `<span class="ai-modal__error">${message}</span>`
    }
    if (this.hasApplyButtonTarget) this.applyButtonTarget.disabled = true
    if (this.hasCopyButtonTarget) this.copyButtonTarget.disabled = true
  }

  setStatus(text, isLoading) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
      this.statusTarget.classList.toggle('ai-modal__status--loading', isLoading)
    }
  }

  getActionLabel(actionType) {
    const labels = {
      improve: 'Improving writing...',
      summarize: 'Summarizing...',
      expand: 'Expanding text...',
      adjust_tone: 'Adjusting tone...',
      research: 'Researching topic...',
      suggest_topics: 'Suggesting topics...',
      break_down_task: 'Breaking down task...'
    }
    return labels[actionType] || 'Processing...'
  }

  renderMarkdown(text) {
    if (!text) return ''

    let content = text.trim()
    if (content.startsWith('```')) {
      content = content.replace(/^```\w*\n?/, '').replace(/\n?```$/, '')
    }

    // Escape HTML
    let html = content
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

    // Code blocks
    html = html.replace(/```(\w*)\n?([\s\S]*?)```/g, '<pre><code>$2</code></pre>')

    // Inline code
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>')

    // Headers
    html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>')
    html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>')
    html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>')

    // Bold & Italic
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>')

    // Blockquotes
    html = html.replace(/^&gt; (.+)$/gm, '<blockquote>$1</blockquote>')

    // Lists
    html = html.replace(/^- (.+)$/gm, '<li>$1</li>')
    html = html.replace(/^\d+\. (.+)$/gm, '<li>$1</li>')
    html = html.replace(/(<li>.*<\/li>\n?)+/g, '<ul>$&</ul>')

    // Paragraphs
    html = html.replace(/\n\n+/g, '</p><p>')
    html = html.replace(/(?<!\>)\n(?!<)/g, '<br>')

    if (!html.match(/^<(h[1-6]|p|ul|ol|pre|blockquote)/)) {
      html = '<p>' + html + '</p>'
    }

    html = html.replace(/<p><\/p>/g, '')

    return html
  }

  getEditor() {
    // Try different editor types used in Fizzy
    return document.querySelector('lexxy-editor') ||
           document.querySelector('trix-editor') ||
           document.querySelector('textarea[data-ai-modal-target="editor"]') ||
           document.querySelector('.card-form textarea') ||
           document.querySelector('textarea.description')
  }

  getEditorContent(editor) {
    if (editor.tagName === 'LEXXY-EDITOR') {
      return typeof editor.getContent === 'function' ? editor.getContent() : editor.value
    }
    if (editor.tagName === 'TRIX-EDITOR') {
      return editor.editor.getDocument().toString()
    }
    return editor.value || editor.textContent || ''
  }

  getEditorSelection(editor) {
    if (editor.tagName === 'LEXXY-EDITOR' && typeof editor.getSelectedText === 'function') {
      const selection = editor.getSelectedText()
      if (selection && selection.trim()) return selection
    }

    if (editor.tagName === 'TRIX-EDITOR') {
      const range = editor.editor.getSelectedRange()
      if (range[0] !== range[1]) {
        return editor.editor.getDocument().getStringAtRange(range)
      }
    }

    if (editor.tagName === 'TEXTAREA') {
      const start = editor.selectionStart
      const end = editor.selectionEnd
      if (start !== end) {
        return editor.value.substring(start, end)
      }
    }

    // Fallback to window selection
    const selection = window.getSelection()
    if (selection && selection.toString().trim()) {
      return selection.toString().trim()
    }

    return null
  }

  cleanup() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    this.isStreaming = false
    this.accumulatedContent = ''
    this.storedSelection = null
    this.storedFullContent = null
  }
}
