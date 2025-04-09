module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    searchable_by :title, using: :cards_search_index

    scope :mentioning, ->(query) do
      if query = sanitize_query_syntax(query)
        cards = Card.search(query).select(:id).to_sql
        comments = Comment.search(query).select(:id).to_sql

        left_joins(:messages).where("cards.id in (#{cards}) or messages.messageable_id in (#{comments})").distinct
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
end
