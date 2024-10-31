module Bubble::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    searchable_by :title, using: :bubbles_search_index

    scope :mentioning, ->(query) do
      bubbles = Bubble.search(query).select(:id).to_sql
      comments = Comment.search(query).select(:id).to_sql
      left_joins(:messages).where("bubbles.id in (#{bubbles}) or messages.messageable_id in (#{comments})").distinct
    end
  end
end
