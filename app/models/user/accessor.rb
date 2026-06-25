module User::Accessor
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :destroy
    has_many :boards, through: :accesses
    has_many :accessible_columns, through: :boards, source: :columns
    has_many :accessible_cards, through: :boards, source: :cards
    has_many :accessible_comments, through: :accessible_cards, source: :comments

    after_create_commit :grant_access_to_boards, unless: :system?
  end

  def draft_new_card_in(board)
    retries = 0
    begin
      board.cards.find_or_initialize_by(creator: self, status: "drafted").tap do |card|
        card.update!(created_at: Time.current, updated_at: Time.current, last_active_at: Time.current)
      end
    rescue ActiveRecord::RecordNotUnique
      if (retries += 1) <= 3
        resync_cards_count_for(board.account)
        retry
      end
      raise
    end
  end

  private
    def resync_cards_count_for(acct)
      acct.reload
      max_number = acct.cards.maximum(:number).to_i
      acct.update_column(:cards_count, max_number) if acct.cards_count < max_number
    end

    def grant_access_to_boards
      Access.insert_all account.boards.all_access.ids.collect { |board_id| { id: ActiveRecord::Type::Uuid.generate, board_id: board_id, user_id: id, account_id: account.id } }
    end
end
