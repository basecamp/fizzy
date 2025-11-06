module User::Accessor
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :destroy
    has_many :boards, through: :accesses
    has_many :accessible_cards, through: :boards, source: :cards
    has_many :accessible_comments, through: :accessible_cards, source: :comments

    after_create_commit :grant_access_to_boards, unless: :system?
  end

  private
    def grant_access_to_boards
      Access.insert_all Board.all_access.pluck(:id).collect { |board_id| { board_id: board_id, user_id: id } }
    end
end
