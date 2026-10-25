module Board::Entropic
  extend ActiveSupport::Concern

  included do
    delegate :auto_postpone_period, :auto_postpone_period_in_days, to: :entropy
    has_one :entropy, as: :container, dependent: :destroy, autosave: true
  end

  def entropy
    super || account.entropy
  end

  def auto_postpone_period=(new_value)
    (association(:entropy).reader || build_entropy).auto_postpone_period = new_value
  end

  def auto_postpone_period_in_days=(value)
    self.auto_postpone_period = value.to_i.days.to_i
  end
end
