# rbs_inline: enabled

class Search::Query < ApplicationRecord
  belongs_to :account, default: -> do
    # @type self: Search::Query
    user&.account || Current.account
  end
  belongs_to :user, optional: true

  validates :terms, presence: true
  before_validation :sanitize_terms

  delegate :to_s, to: :terms

  class << self
    #: (untyped) -> Search::Query
    def wrap(query)
      if query.is_a?(self)
        query
      else
        self.new(terms: query)
      end
    end
  end

  private
    #: -> void
    def sanitize_terms
      # mais um caso de nilable que deve ser tratado no design
      terms
      self.terms = sanitize(terms)
    end

    #: (String?) -> String?
    def sanitize(terms)
      if terms.present?
        terms = remove_invalid_search_characters(self.terms)
        terms = remove_unbalanced_quotes(terms)
        terms.presence
      else
        terms
      end
    end

    #: (String) -> String
    def remove_invalid_search_characters(terms)
      terms.gsub(/[^\w"]/, " ")
    end

    #: (String) -> String
    def remove_unbalanced_quotes(terms)
      if terms.count("\"").even?
        terms
      else
        terms.gsub("\"", " ")
      end
    end
end
