class Search::RefreshEmbeddingJob < ApplicationJob
  def perform(record)
    record.refresh_search_embedding
  end
end
