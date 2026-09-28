class Card::ReindexCommentsJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(card)
    card.reindex_comments
  end
end
