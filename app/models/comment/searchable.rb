# rbs_inline: enabled

module Comment::Searchable
  extend ActiveSupport::Concern

  # @type self: singleton(Comment) & singleton(Comment::Searchable)

  included do
    include ::Searchable
  end

  def search_title
    nil
  end

  def search_content
    body.to_plain_text
  end

  #: -> String
  def search_card_id
    # @type self: Comment & Comment::Searchable
    card_id
  end

  #: -> String
  def search_board_id
    # @type self: Comment & Comment::Searchable
    card.board_id
  end
end
