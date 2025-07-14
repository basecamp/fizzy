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
    content_tag "lexical-prompt", "", trigger: "#", src: prompts_cards_path, name: "card", "insert-editable-text": true, "remote-filtering": true
  end

  def rich_link_unfurl_url
    File.join(request.script_name, RichLink::Engine.routes.url_helpers.unfurl_path)
  end
end
