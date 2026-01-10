class Card::ActivitySpike::DetectionJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(card)
    card.detect_activity_spikes
  end
end
