module WebhooksHelper
  ACTION_LABELS = {
    card_assigned: "Card assigned",
    card_closed: "Card closed",
    card_collection_changed: "Card collection changed",
    card_due_date_added: "Card due date added",
    card_due_date_changed: "Card due date changed",
    card_due_date_removed: "Card due date removed",
    card_published: "Card published",
    card_reopened: "Card reopened",
    card_title_changed: "Card title changed",
    card_unassigned: "Card unassigned",
    card_unstaged: "Card unstaged",
    comment_created: "Comment created"
  }.with_indifferent_access.freeze

  def webhook_action_options(actions = Webhook::PERMITTED_ACTIONS)
    actions.each_with_object({}) do |action, hash|
      hash[action.to_s] = webhook_action_label(action)
    end
  end

  def webhook_action_label(action)
    ACTION_LABELS[action] || action.to_s.humanize
  end
end
