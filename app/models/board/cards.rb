module Board::Cards
  extend ActiveSupport::Concern

  included do
    has_many :cards, dependent: :destroy

    after_update_commit -> { cards.touch_all }, if: :saved_change_to_name?
  end
end
