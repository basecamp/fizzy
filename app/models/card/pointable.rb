module Card::Pointable
  extend ActiveSupport::Concern

  included do
    validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  end

  def award_points_on_close
    if points.present? && assignees.any?
      closure.update!(points_awarded: points)
    end
  end
end
