module Search::Record::SQLite
  extend ActiveSupport::Concern

  included do
    attribute :result_title, :string
    attribute :result_content, :string

    has_one :search_records_fts, -> { with_rowid },
      class_name: "Search::Record::SQLite::Fts", foreign_key: :rowid, primary_key: :id, dependent: :destroy

    after_save :upsert_to_fts5_table

    scope :matching, ->(query, account_id) { joins(:search_records_fts).where("search_records_fts MATCH ?", query) }
  end

  class_methods do
    def search_fields(query)
      opening_mark = connection.quote(Search::Highlighter::OPENING_MARK)
      closing_mark = connection.quote(Search::Highlighter::CLOSING_MARK)
      ellipsis = connection.quote(Search::Highlighter::ELIPSIS)

      [ "highlight(search_records_fts, 0, #{opening_mark}, #{closing_mark}) AS result_title",
        "snippet(search_records_fts, 1, #{opening_mark}, #{closing_mark}, #{ellipsis}, 20) AS result_content",
        "#{connection.quote(query.terms)} AS query" ]
    end

    def for(account_id)
      self
    end
  end

  def card_title
    escape_fts_highlight(result_title || card.title)
  end

  def card_description
    escape_fts_highlight(result_content) unless comment
  end

  def comment_body
    escape_fts_highlight(result_content) if comment
  end

  private
    def escape_fts_highlight(html)
      return nil unless html.present?

      CGI.escapeHTML(html)
        .gsub(CGI.escapeHTML(Search::Highlighter::OPENING_MARK), Search::Highlighter::OPENING_MARK)
        .gsub(CGI.escapeHTML(Search::Highlighter::CLOSING_MARK), Search::Highlighter::CLOSING_MARK)
        .html_safe
    end

    def upsert_to_fts5_table
      Fts.upsert(id, title, content)
    end
end
