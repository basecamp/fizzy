module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    scope :mentioning, ->(query, user:) do
      search_record_class = Search::Record.for(user.account_id)
      joins(search_record_class.card_join).merge(search_record_class.for_query(query, user: user))
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

  def searchable?
    published?
  end
end
