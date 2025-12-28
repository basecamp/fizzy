# rbs_inline: enabled

class Webhook::DelinquencyTracker < ApplicationRecord
  DELINQUENCY_THRESHOLD = 10
  DELINQUENCY_DURATION = 1.hour

  belongs_to :account, default: -> do
    # @type self: Webhook::DelinquencyTracker
    webhook.account
  end
  belongs_to :webhook

  def record_delivery_of(delivery)
    if delivery.succeeded?
      reset
    else
      mark_first_failure_time if consecutive_failures_count.zero?
      increment!(:consecutive_failures_count, touch: true)

      webhook.deactivate if delinquent?
    end
  end

  private
    def reset
      update_columns consecutive_failures_count: 0, first_failure_at: nil
    end

    def mark_first_failure_time
      update_columns first_failure_at: Time.current
    end

    def delinquent?
      failing_for_too_long? && too_many_consecutive_failures?
    end

    def failing_for_too_long?
      if first_failure_at
        first_failure_at.before?(DELINQUENCY_DURATION.ago)
      else
        false
      end
    end

    def too_many_consecutive_failures?
      consecutive_failures_count >= DELINQUENCY_THRESHOLD
    end
end
