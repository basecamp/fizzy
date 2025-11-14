class Search::Query < ApplicationRecord
  belongs_to :account, default: -> { user&.account || Current.account }
  belongs_to :user, optional: true

  validates :terms, presence: true
  before_validation :sanitize_terms

  class << self
    def wrap(query)
      if query.is_a?(self)
        query
      else
        self.new(terms: query)
      end
    end
  end

  def to_s
    Search::Stemmer.stem(terms.to_s)
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
