class Card::RemoveInaccessibleNotificationsJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(card)
    card.remove_inaccessible_notifications
  end
end
