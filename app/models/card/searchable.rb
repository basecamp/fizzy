# rbs_inline: enabled

module Card::Searchable
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Searchable)

  included do
    include ::Searchable

    scope :mentioning, ->(query, user:) do
      search_record_class = Search::Record.for(user.account_id)
      joins(search_record_class.card_join).merge(search_record_class.for_query(query, user: user))
    end
  end

  def search_title
    # @type self: Card & Card::Searchable
    title
  end

  def search_content
    # @type self: Card & Card::Searchable
    description.to_plain_text
  end

  def search_card_id
    # @type self: Card & Card::Searchable
    id
  end

  def search_board_id
    # @type self: Card & Card::Searchable
    board_id
  end
end
