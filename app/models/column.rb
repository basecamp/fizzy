class Column < ApplicationRecord
  include Positioned

  belongs_to :board, touch: true
  has_many :cards, dependent: :nullify

  before_validation    -> { self.color ||= Card::DEFAULT_COLOR }
  after_save_commit    -> { cards.touch_all }, if: -> { saved_change_to_name? || saved_change_to_color? }
  after_destroy_commit -> { board.cards.touch_all }
end
