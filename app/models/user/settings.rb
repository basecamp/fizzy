class User::Settings < ApplicationRecord
  belongs_to :user

  enum :bundle_email_frequency, %i[ never every_few_hours daily weekly ],
    default: :every_few_hours, prefix: :bundle_email

  after_update :review_pending_bundles, if: :saved_change_to_bundle_email_frequency?

  def bundle_aggregation_period
    case bundle_email_frequency
    when "every_few_hours"
      4.hours
    when "daily"
      1.day
    when "weekly"
      1.week
    else
      1.day
    end
  end

  def bundling_emails?
    !bundle_email_never? && !user.system? && user.active?
  end

  def timezone
    if timezone_name.present?
      ActiveSupport::TimeZone[timezone_name] || default_timezone
    else
      default_timezone
    end
  end

  private
    def review_pending_bundles
      if bundling_emails?
        flush_pending_bundles
      else
        cancel_pending_bundles
      end
    end

    def cancel_pending_bundles
      user.notification_bundles.pending.find_each do |bundle|
        bundle.destroy
      end
    end

    def flush_pending_bundles
      user.notification_bundles.pending.find_each(&:flush)
    end

    def default_timezone
      ActiveSupport::TimeZone["UTC"]
    end
end
