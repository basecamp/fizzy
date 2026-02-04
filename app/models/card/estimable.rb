module Card::Estimable
  extend ActiveSupport::Concern

  included do
    validates :business_value, inclusion: { in: 1..10 }, allow_nil: true
    validates :difficulty, inclusion: { in: 1..10 }, allow_nil: true
    validates :estimate_hours, numericality: { greater_than: 0 }, allow_nil: true
    validates :remaining_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    scope :estimated, -> { where.not(estimate_hours: nil) }
    scope :unestimated, -> { where(estimate_hours: nil) }
  end

  def estimated?
    estimate_hours.present?
  end

  def total_estimate_points
    return 0 unless estimated?
    (business_value || 0) + (difficulty || 0)
  end

  # Actual remaining work (supports partial completion)
  def actual_remaining_hours
    return 0 if closed?
    remaining_hours || estimate_hours || 0
  end

  # Percentage complete
  def completion_percentage
    return 100 if closed?
    return 0 unless estimate_hours.present? && estimate_hours > 0
    
    actual_remaining = remaining_hours || estimate_hours
    completed = estimate_hours - actual_remaining
    ((completed.to_f / estimate_hours) * 100).round
  end
end
