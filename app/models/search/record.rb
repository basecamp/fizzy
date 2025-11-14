class Search::Record < ApplicationRecord
  self.abstract_class = true

  SHARD_COUNT = 16

  SHARD_CLASSES = SHARD_COUNT.times.map do |shard_id|
    Class.new(self) do
      self.table_name = "search_records_#{shard_id}"

      def self.name
        "Search::Record"
      end
    end
  end.freeze

  belongs_to :searchable, polymorphic: true
  belongs_to :card

  # Virtual attributes from search query
  attribute :query, :string

  validates :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :created_at, presence: true

  class << self
    def for_account(account_id)
      SHARD_CLASSES[shard_id_for_account(account_id)]
    end

    def shard_id_for_account(account_id)
      Zlib.crc32(account_id.to_s) % SHARD_COUNT
    end

    def card_join
      "INNER JOIN #{table_name} ON #{table_name}.card_id = cards.id"
    end
  end

  scope :for_query, ->(query:, user:) do
    if query.valid? && user.board_ids.any?
      matching(query.to_s).for_user(user)
    else
      none
    end
  end

  scope :matching, ->(query) do
    where("MATCH(#{table_name}.content, #{table_name}.title) AGAINST(? IN BOOLEAN MODE)", query)
  end

  scope :for_user, ->(user) do
    where(account_id: user.account_id, board_id: user.board_ids)
  end

  scope :search, ->(query:, user:) do
    for_query(query: query, user: user)
      .includes(:searchable, card: [ :board, :creator ])
      .select(:id, :searchable_type, :searchable_id, :card_id, :board_id, :account_id, :created_at, "#{connection.quote(query.terms)} AS query")
      .order(created_at: :desc)
  end

  def source
    searchable_type == "Comment" ? searchable : card
  end

  def comment
    searchable if searchable_type == "Comment"
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
end
