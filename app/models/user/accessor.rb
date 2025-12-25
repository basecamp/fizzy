# rbs_inline: enabled

module User::Accessor
  extend ActiveSupport::Concern

  # @type self: singleton(User) & singleton(User::Accessor)

  included do
    has_many :accesses, dependent: :destroy
    has_many :boards, through: :accesses
    has_many :accessible_columns, through: :boards, source: :columns
    has_many :accessible_cards, through: :boards, source: :cards
    has_many :accessible_comments, through: :accessible_cards, source: :comments

    after_create_commit :grant_access_to_boards, unless: :system?
  end

  private
    def grant_access_to_boards
      # @type self: User & User::Accessor
      Access.insert_all account.boards.all_access.pluck(:id).collect { |board_id| { id: ActiveRecord::Type::Uuid.generate, board_id: board_id, user_id: id, account_id: account.id } }
    end
end
