# rbs_inline: enabled

module Column::Colored
  extend ActiveSupport::Concern

  DEFAULT_COLOR = Color::COLORS.first

  # @type self: singleton(Column) & singleton(Column::Colored)
  # @type instance: Column & Column::Colored

  included do
    before_validation -> { self[:color] ||= DEFAULT_COLOR.value }
  end

  #: -> Color
  def color
    Color.for_value(super) || DEFAULT_COLOR
  end
end
