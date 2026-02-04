module Card::Estimable
  extend ActiveSupport::Concern

  included do
    validates :business_value, inclusion: { in: 1..10 }, allow_nil: true
    validates :difficulty, inclusion: { in: 1..10 }, allow_nil: true
    validates :estimate_hours, numericality: { greater_than: 0 }, allow_nil: true

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
end
