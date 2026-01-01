# rbs_inline: enabled

module Card::Colored
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Colored)
  # @type instance: Card & Card::Colored

  #: -> Color
  def color
    column&.color || Column::Colored::DEFAULT_COLOR
  end
end
