# rbs_inline: enabled

class Search::Record < ApplicationRecord
  include const_get(connection.adapter_name)

  belongs_to :searchable, polymorphic: true
  belongs_to :card

  validates :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :created_at, presence: true

  class << self
    #: (Hash[untyped, untyped]) -> Search::Record
    def upsert!(attributes)
      record = find_by(searchable_type: attributes[:searchable_type], searchable_id: attributes[:searchable_id])
      if record
        record.update!(attributes)
        record
      else
        create!(**attributes)
      end
    end

    #: -> String
    def card_join
      "INNER JOIN #{table_name} ON #{table_name}.card_id = cards.id"
    end
  end

  scope :for_query, ->(query, user:) do
    query = Search::Query.wrap(query)

    if query.valid? && user.board_ids.any?
      matching(query.to_s, user.account_id).where(account_id: user.account_id, board_id: user.board_ids)
    else
      none
    end
  end

  scope :search, ->(query, user:) do
    query = Search::Query.wrap(query)

    for_query(query, user: user)
      .includes(:searchable, card: [ :board, :creator ])
      .order(created_at: :desc)
      .select(:id, :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :title, :content, :created_at, *search_fields(query))
  end

  def source
    searchable_type == "Comment" ? searchable : card
  end

  def comment
    searchable if searchable_type == "Comment"
  end
end
