class Card::BroadcastPinUpdatesJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(card)
    card.broadcast_pin_updates
  end
end
