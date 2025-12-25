class Column < ApplicationRecord
  include Colored, Positioned

  belongs_to :account, default: -> do
    # @type self: Column
    board.account
  end
  belongs_to :board, touch: true
  has_many :cards, dependent: :nullify

  after_save_commit    -> { cards.touch_all }, if: -> { saved_change_to_name? || saved_change_to_color? }
  after_destroy_commit -> { board.cards.touch_all }
end
