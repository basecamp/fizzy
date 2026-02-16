class Search::Query < ApplicationRecord
  belongs_to :account, default: -> { user&.account || Current.account }
  belongs_to :user, optional: true

  validates :terms, presence: true
  before_validation :sanitize_terms

  delegate :to_s, to: :terms

  class << self
    def wrap(query)
      if query.is_a?(self)
        query
      else
        self.new(terms: query)
      end
    end
  end

  private
    def sanitize_terms
      self.terms = sanitize(terms)
    end

    def sanitize(terms)
      if terms.present?
        terms = remove_invalid_search_characters(self.terms)
        terms = remove_unbalanced_quotes(terms)
        terms.presence
      else
        terms
      end
    end

    def remove_invalid_search_characters(terms)
      terms.gsub(/[^\p{L}\p{N}_"]/, " ")
    end

    def remove_unbalanced_quotes(terms)
      if terms.count("\"").even?
        terms
      else
        terms.gsub("\"", " ")
      end
    end
end
