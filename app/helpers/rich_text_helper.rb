module RichTextHelper
  def mentions_prompt(collection)
    content_tag "lexical-prompt", "", trigger: "@", src: prompts_collection_users_path(collection), name: "mention"
  end

  def global_mentions_prompt
    content_tag "lexical-prompt", "", trigger: "@", src: prompts_users_path, name: "mention"
  end

  def tags_prompt
    content_tag "lexical-prompt", "", trigger: "#", src: prompts_tags_path, name: "tag"
  end

  def commands_prompt
    content_tag "lexical-prompt", "", trigger: "/", src: prompts_commands_path, name: "command", "insert-editable-text": true
  end

  def cards_prompt
    content_tag "lexical-prompt", "", trigger: "#", src: prompts_cards_path, name: "card", "insert-editable-text": true, "remote-filtering": true, "supports-space-in-searches": true
  end

  def code_language_picker
    content_tag "lexical-code-language-picker"
  end

  def general_prompts(collection)
    safe_join([ mentions_prompt(collection), cards_prompt, code_language_picker ])
  end
end
