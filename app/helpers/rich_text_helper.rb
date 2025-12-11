module RichTextHelper
  def mentions_prompt(board)
    content_tag "lexxy-prompt", "", trigger: "@", src: prompts_board_users_path(board), name: "mention"
  end

  def global_mentions_prompt
    content_tag "lexxy-prompt", "", trigger: "@", src: prompts_users_path, name: "mention"
  end

  def tags_prompt
    content_tag "lexxy-prompt", "", trigger: "#", src: prompts_tags_path, name: "tag"
  end

  def cards_prompt
    content_tag "lexxy-prompt", "", trigger: "#", src: prompts_cards_path, name: "card", "insert-editable-text": true, "remote-filtering": true, "supports-space-in-searches": true
  end

  def code_language_picker
    content_tag "lexxy-code-language-picker"
  end

  def ai_assistant_toolbar
    content_tag :div, class: "ai-assistant-toolbar", data: { controller: "ai-assistant" } do
      safe_join([
        ai_assistant_button("Improve", "improve", "Improve clarity and grammar"),
        ai_assistant_button("Summarize", "summarize", "Summarize into key points"),
        ai_assistant_button("Expand", "expand", "Expand notes into prose"),
        ai_assistant_button("Research", "research", "Research this topic"),
        ai_assistant_button("Break down", "breakDown", "Break into subtasks"),
        ai_loading_indicator
      ])
    end
  end

  def ai_assistant_button(label, action, title)
    content_tag :button, label,
      type: "button",
      title: title,
      class: "ai-assistant-btn",
      data: { action: "click->ai-assistant##{action}" }
  end

  def ai_loading_indicator
    content_tag :span, "Working...",
      class: "ai-loading-indicator hidden",
      data: { "ai-assistant-target": "loading" }
  end

  def general_prompts(board)
    safe_join([ mentions_prompt(board), cards_prompt, code_language_picker ])
  end
end
