module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    searchable_by :title_and_description, using: :cards_search_index, as: :title

    scope :mentioning, ->(query) do
      if query = sanitize_query_syntax(query)
        cards = Card.search_similar(query).select(:id).to_sql
        comments = Comment.search_similar(query).select(:id).to_sql

        left_joins(:comments).where("cards.id in (#{cards}) or comments.id in (#{comments})").distinct
      else
        none
      end
    end
  end

  class_methods do
    def sanitize_query_syntax(terms)
      terms = terms.to_s
      terms = remove_invalid_search_characters(terms)
      terms = remove_unbalanced_quotes(terms)
      terms.presence
    end

    private
      def remove_invalid_search_characters(terms)
        terms.gsub(/[^\w"]/, " ")
      end

      def remove_unbalanced_quotes(terms)
        if terms.count("\"").even?
          terms
        else
          terms.gsub("\"", " ")
        end
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
