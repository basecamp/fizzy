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
        terms = remove_unbalanced_quotes(self.terms)
        terms = quote_joined_words(terms)
        terms = remove_invalid_search_characters(terms)
        terms.presence
      else
        terms
      end
    end

    def remove_unbalanced_quotes(terms)
      if terms.count("\"").even?
        terms
      else
        terms.gsub("\"", " ")
      end
    end

    def quote_joined_words(terms)
      terms.gsub(/"[^"]*"|\w+(?:[^\w[:space:]\u200B"]+\w+)+/) { |match| match.start_with?("\"") ? match : "\"#{match}\"" }
    end

    def remove_invalid_search_characters(terms)
      terms.gsub(/[^\w"]/, " ")
    end
end
