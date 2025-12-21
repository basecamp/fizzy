module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    scope :mentioning, ->(query, user:) do
      search_record_class = Search::Record.for(user.account_id)
      joins(search_record_class.card_join).merge(search_record_class.for_query(query, user: user))
    end
  end

  class_methods do
    def mentioning_all(terms, user:)
      query = combined_terms_fts_query(terms)
      mentioning(query, user: user)
    end

    private

    def combined_terms_fts_query(terms)
      terms.map { |term| sanitize_fts_term(term) }.join(' AND ')
    end

    def sanitize_fts_term(term)
      term.gsub('"', '""').then { |t| "\"#{t}\"*" }
    end
  end

  def search_title
    title
  end

  def search_content
    description.to_plain_text
  end

  def search_card_id
    id
  end

  def search_board_id
    board_id
  end
end
