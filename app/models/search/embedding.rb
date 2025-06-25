class Search::Embedding < ApplicationRecord
  self.table_name = "search_embeddings"

  belongs_to :record, polymorphic: true
end
