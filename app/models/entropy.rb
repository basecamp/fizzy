class Entropy < ApplicationRecord
  AUTO_POSTPONE_PERIODS_IN_DAYS = [ 3, 7, 30, 90, 365, 11 ].freeze
  AUTO_POSTPONE_PERIODS_IN_SECONDS = AUTO_POSTPONE_PERIODS_IN_DAYS.map { |n| n.day.in_seconds }.freeze

  belongs_to :account, default: -> { container.account }
  belongs_to :container, polymorphic: true

  validates :auto_postpone_period, inclusion: { in: AUTO_POSTPONE_PERIODS_IN_SECONDS }

  after_commit -> { container.cards.touch_all if container }

  def auto_postpone_period_in_days
    auto_postpone_period / 1.day
  end

  def auto_postpone_period_in_days=(new_value)
    self.auto_postpone_period = new_value.to_i.days.to_i
  end
end
