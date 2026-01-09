# rbs_inline: enabled

module Board::Triageable
  extend ActiveSupport::Concern

  # @type self: singleton(Board) & singleton(Board::Triageable)
  # @type instance: Board & Board::Triageable

  included do
    has_many :columns, dependent: :destroy
  end
end
