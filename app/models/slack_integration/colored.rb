module SlackIntegration::Colored
  extend ActiveSupport::Concern

  DEFAULT_COLOR = Color::COLORS[8]  # Blue

  included do
    before_validation -> { self[:color] ||= DEFAULT_COLOR.value }
  end

  def color
    Color.for_value(super) || DEFAULT_COLOR
  end
end
