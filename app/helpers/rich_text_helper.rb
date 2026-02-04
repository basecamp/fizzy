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

  def general_prompts(board)
    safe_join([ mentions_prompt(board), cards_prompt ])
  end
end
