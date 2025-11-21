module Search::Record::Trilogy
  extend ActiveSupport::Concern

  SHARD_COUNT = 16

  included do
    before_save :set_account_key, :stem_content

    scope :matching, ->(query, account_id) do
      full_query = "+account#{account_id} +(#{Search::Stemmer.stem(query)})"
      where("MATCH(#{table_name}.account_key, #{table_name}.content, #{table_name}.title) AGAINST(? IN BOOLEAN MODE)", full_query)
    end
  end

  class_methods do
    def compute_table_name
      if Current.account
        "search_records_#{shard_id_for_account(Current.account.id)}"
      else
        "search_records"
      end
    end

    def shard_id_for_account(account_id)
      Zlib.crc32(account_id.to_s) % SHARD_COUNT
    end

    def search_fields(query)
      "#{connection.quote(query.terms)} AS query"
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
    def stem_content
      self.title = Search::Stemmer.stem(title) if title_changed?
      self.content = Search::Stemmer.stem(content) if content_changed?
    end

    def set_account_key
      self.account_key = "account#{account_id}"
    end

    def highlight(text, show:)
      if text.present? && attribute?(:query)
        highlighter = Search::Highlighter.new(query)
        show == :snippet ? highlighter.snippet(text) : highlighter.highlight(text)
      else
        text
      end
    end
end
