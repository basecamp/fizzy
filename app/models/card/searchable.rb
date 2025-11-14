module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    scope :mentioning, ->(query, user:) do
      search_records = Search::Record.for_account(user.account_id)

      joins(search_records.card_join)
        .merge(search_records.for_query(query: Search::Query.wrap(query), user: user))
    end
  end

  def search_title
    title
  end

  def search_content
    description.to_plain_text
  end

  def search_card_id
    id
  end

  def search_board_id
    board_id
  end
end
