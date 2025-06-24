module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    searchable_by :title, :description, using: :cards_search_index

    scope :mentioning, ->(query) do
      cards = Card.search(query).select(:id).to_sql
      comments = Comment.search(query).select(:id).to_sql

      left_joins(:comments).where("cards.id in (#{cards}) or comments.id in (#{comments})").distinct
    end

    scope :similar_to, ->(query) do
      cards = Card.search_similar(query).select(:id).to_sql
      comments = Comment.search_similar(query).select(:id).to_sql

      left_joins(:comments).where("cards.id in (#{cards}) or comments.id in (#{comments})").distinct
    end
  end

  private
    # TODO: Temporary until we stabilize the search API
    def title_and_description
      [ title, description.to_plain_text ].join(" ")
    end

    def search_embedding_content
      <<~CONTENT
        Title: #{title}
        Description: #{description.to_plain_text}
        Created by: #{creator.name}}
        Assigned to: #{assignees.map(&:name).join(", ")}}
      CONTENT
    end
end
