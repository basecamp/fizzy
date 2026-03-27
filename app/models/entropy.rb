class Entropy < ApplicationRecord
  DEFAULT_AUTO_POSTPONE_PERIOD_IN_DAYS = 30
  AUTO_POSTPONE_PERIODS_IN_DAYS = [ 3, 7, 30, 90, 365, 11 ].freeze
  AUTO_POSTPONE_PERIODS_IN_SECONDS = AUTO_POSTPONE_PERIODS_IN_DAYS.map { |n| n.day.in_seconds }.freeze

  belongs_to :account, default: -> { container.account }
  belongs_to :container, polymorphic: true

  validates :auto_postpone_period, inclusion: { in: AUTO_POSTPONE_PERIODS_IN_SECONDS }

  after_commit -> { container.cards.touch_all if container }

  def auto_postpone_period_in_days
    days = auto_postpone_period / 1.day.to_i

    if days.in?(AUTO_POSTPONE_PERIODS_IN_DAYS)
      days
    else
      default_auto_postpone_period_in_days
    end
  end

  def auto_postpone_period_in_days=(new_value)
    self.auto_postpone_period = new_value.to_i.days.to_i
  end

  private
    def default_auto_postpone_period_in_days
      if container.is_a?(Board)
        container.account.entropy.auto_postpone_period_in_days
      else
        DEFAULT_AUTO_POSTPONE_PERIOD_IN_DAYS
      end
    end
end
