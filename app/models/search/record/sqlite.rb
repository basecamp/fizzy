module Search::Record::SQLite
  extend ActiveSupport::Concern

  included do
    has_one :search_records_fts, -> { with_rowid },
      class_name: "Search::Record::SQLite::Fts", foreign_key: :rowid, primary_key: :id, dependent: :destroy

    after_save :upsert_to_fts5_table

    scope :matching, ->(query, account_id) {
      joins("INNER JOIN search_records_fts ON search_records_fts.rowid = #{table_name}.id")
        .where("search_records_fts MATCH ?", Search::Stemmer.stem_query(query.to_s))
    }
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
    highlight_full(card.title) if card_id
  end

  def card_description
    highlight_snippet(card.description.to_plain_text) if card_id
  end

  def comment_body
    highlight_snippet(comment.body.to_plain_text) if comment
  end

  private
    def highlight_snippet(text)
      if text.present? && attribute?(:query)
        Search::Highlighter.new(query).snippet(text)
      else
        text
      end
    end

    def highlight_full(text)
      if text.present? && attribute?(:query)
        Search::Highlighter.new(query).highlight(text)
      else
        text
      end
    end

    def upsert_to_fts5_table
      Fts.upsert(id, Search::Stemmer.stem(title), Search::Stemmer.stem(content))
    end
end
