module Search::Record::SQLite
  extend ActiveSupport::Concern

  included do
    has_one :search_records_fts, -> { with_rowid },
      class_name: "Search::Record::SQLite::Fts", foreign_key: :rowid, primary_key: :id, dependent: :destroy

    after_save :upsert_to_fts5_table

    scope :matching, ->(query, account_id) { joins(:search_records_fts).where("search_records_fts MATCH ?", Search::Stemmer.stem(query.to_s)) }
  end

  class_methods do
    def search_fields(query)
      "#{connection.quote(query.terms)} AS query"
    end

    def for(account_id)
      self
    end
  end

  def card_title
    highlight(card.title, show: :full) if card_id
  end

  def card_description
    highlight(card.description.to_plain_text, show: :snippet) if card_id
  end

  def comment_body
    highlight(comment.body.to_plain_text, show: :snippet) if comment
  end

  private
    def highlight(text, show:)
      if text.present? && attribute?(:query)
        highlighter = Search::Highlighter.new(query)
        show == :snippet ? highlighter.snippet(text) : highlighter.highlight(text)
      else
        text
      end
    end

    def upsert_to_fts5_table
      Fts.upsert(id, Search::Stemmer.stem(title), Search::Stemmer.stem(content))
    end
end
