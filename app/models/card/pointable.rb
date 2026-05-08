module Card::Pointable
  extend ActiveSupport::Concern

  def award_points_on_close
    if points.present? && assignees.any?
      closure.update!(points_awarded: points)
    end
  end
end
