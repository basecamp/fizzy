class Card::CleanInaccessibleDataJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(card)
    card.clean_inaccessible_data
  end
end
