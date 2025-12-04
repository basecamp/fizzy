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

  def general_prompts(board)
    safe_join([ mentions_prompt(board), cards_prompt, code_language_picker ])
  end

  def lexxy_rich_textarea_tag(name, value = nil, options = {}, &block)
    options = options.symbolize_keys
    unfurl_links = options.key?(:unfurl_links) ? options.delete(:unfurl_links) : true

    if unfurl_links
      data = options[:data] ||= {}

      data[:controller] = token_list(data[:controller], "unfurl-link")
      data[:unfurl_link_url_value] ||= unfurl_link_path
      data[:unfurl_link_set_up_basecamp_integration_url_value] ||= new_basecamp_integration_url
      data[:action] = token_list(data[:action], "lexxy:insert-link->unfurl-link#unfurl")
    end

    super(name, value, options) do
      concat link_unfurling_prompt if unfurl_links
      concat capture(&block) if block_given?
    end
  end

  private
    def link_unfurling_prompt
      content_tag(:div, hidden: true, class: "unfurl-notice flex gap justify-space-between align-center", data: { unfurl_link_target: "linkAccountsPrompt" }) do
        concat content_tag(:p, "Connect your account to get previews of Basecamp links?")
        concat(
          content_tag(:div, class: "flex gap-half") do
            concat button_tag("Yes, connect…", class: "btn btn--link", data: { action: "unfurl-link#setUpBasecampIntegration" })
            concat button_tag("Not now", class: "btn fill-transparent", data: { action: "unfurl-link#closePrompt", unfurl_link_intent_param: "dismiss" })
          end
        )
      end
    end
end
