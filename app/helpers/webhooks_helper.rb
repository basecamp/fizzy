module WebhooksHelper
  ACTION_LABELS = {
    card_published: "Card added",
    card_title_changed: "Card title changed",
    card_board_changed: "Card board changed",
    comment_created: "Comment added",
    card_assigned: "Card assigned",
    card_unassigned: "Card unassigned",
    card_triaged: "Card column changed",
    card_closed: "Card moved to “Done”",
    card_reopened: "Card reopened",
    card_postponed: "Card moved to “Not Now”",
    card_auto_postponed: "Card moved to “Not Now” due to inactivity",
    card_sent_back_to_triage: "Card moved back to “Maybe?”"
  }.with_indifferent_access.freeze

  def webhook_action_options(actions = Webhook::PERMITTED_ACTIONS)
    ACTION_LABELS.select { |key, _| actions.include?(key.to_s) }
  end

  def webhook_action_label(action)
    ACTION_LABELS[action] || action.to_s.humanize
  end

  def link_to_webhooks(board, &)
    link_to board_webhooks_path(board_id: board),
        class: [ "btn btn--circle-mobile", { "btn--reversed": board.webhooks.any? } ],
        data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: "Webhooks" } do
      icon_tag("world") + tag.span("Webhooks", class: "for-screen-reader")
    end
  end
end
