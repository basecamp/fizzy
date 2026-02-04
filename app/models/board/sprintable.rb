module Board::Sprintable
  extend ActiveSupport::Concern

  included do
    validates :available_hours, numericality: { greater_than: 0 }, allow_nil: true
    validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }

    scope :with_sprint, -> { where.not(start_date: nil, end_date: nil) }
    scope :without_sprint, -> { where(start_date: nil).or(where(end_date: nil)) }
    scope :active_sprints, -> { with_sprint.where("start_date <= ? AND end_date >= ?", Date.current, Date.current) }
  end

  def sprint_configured?
    start_date.present? && end_date.present?
  end

  def sprint_active?
    sprint_configured? && Date.current.between?(start_date, end_date)
  end

  def sprint_days
    return 0 unless sprint_configured?
    (end_date - start_date).to_i + 1
  end

  def sprint_days_remaining
    return 0 unless sprint_configured?
    return 0 if Date.current > end_date
    (end_date - Date.current).to_i + 1
  end

  def sprint_progress_percentage
    return 0 unless sprint_configured?
    return 100 if Date.current > end_date
    return 0 if Date.current < start_date
    
    total_days = sprint_days
    elapsed_days = (Date.current - start_date).to_i + 1
    ((elapsed_days.to_f / total_days) * 100).round
  end

  private
    def end_date_after_start_date
      if end_date <= start_date
        errors.add(:end_date, "must be after start date")
      end
    end
end
