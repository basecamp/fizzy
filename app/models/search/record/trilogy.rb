module Search::Record::Trilogy
  extend ActiveSupport::Concern

  SHARD_COUNT = 16

  included do
    self.abstract_class = true
    before_save :set_account_key, :stem_content

    scope :matching, ->(query, account_id) do
      full_query = "+account#{account_id} +(#{Search::Stemmer.stem_query(query)})"
      where("MATCH(#{table_name}.account_key, #{table_name}.content, #{table_name}.title) AGAINST(? IN BOOLEAN MODE)", full_query)
    end

    SHARD_CLASSES = SHARD_COUNT.times.map do |shard_id|
      Class.new(self) do
        self.table_name = "search_records_#{shard_id}"

        def self.name
          "Search::Record"
        end
      end
    end.freeze
  end

  class_methods do
    def shard_id_for_account(account_id)
      Zlib.crc32(account_id.to_s) % SHARD_COUNT
    end

    def search_fields(query)
      "#{connection.quote(query.terms)} AS query"
    end

    def for(account_id)
      SHARD_CLASSES[shard_id_for_account(account_id)]
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
    def stem_content
      self.title = Search::Stemmer.stem(title).truncate(255, omission: "") if title_changed?
      self.content = Search::Stemmer.stem(content) if content_changed?
    end

    def set_account_key
      self.account_key = "account#{account_id}"
    end

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
end
