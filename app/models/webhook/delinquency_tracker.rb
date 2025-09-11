class Webhook::DelinquencyTracker < ApplicationRecord
  RESET_INTERVAL = 12.hours
  MINIMUM_DELIVERIES = 50

  belongs_to :webhook

  before_validation { self.last_reset_at ||= Time.current }

  def record_delivery_of(delivery)
    if reset_due?
      webhook.deactivate if delinquent?
      reset
    else
      increment!(:total_count)
      increment!(:failed_count) unless delivery.succeeded?
    end
  end

  private
    def delinquent?
      significantly_active? && all_deliveries_failed?
    end

    def significantly_active?
      total_count >= MINIMUM_DELIVERIES
    end

    def all_deliveries_failed?
      failed_count == total_count
    end

    def reset
      update_columns total_count: 0, failed_count: 0, last_reset_at: Time.current
    end

    def reset_due?
      last_reset_at.before?(RESET_INTERVAL.ago)
    end
end
