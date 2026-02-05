module WebhooksHelper
  def webhook_action_options(actions = Webhook::PERMITTED_ACTIONS)
    actions.index_with { |action| webhook_action_label(action) }
  end

  def webhook_action_label(action)
    key = "webhooks.actions.#{action}"
    I18n.exists?(key) ? I18n.t(key) : action.to_s.humanize
  end

  def link_to_webhooks(board, &)
    link_to board_webhooks_path(board_id: board),
        class: [ "btn btn--circle-mobile", { "btn--reversed": board.webhooks.any? } ],
        data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: t("webhooks.label") } do
      icon_tag("world") + tag.span(t("webhooks.label"), class: "for-screen-reader")
    end
  end
end
