class User::Settings < ApplicationRecord
  belongs_to :account, default: -> { user.account }
  belongs_to :user

  enum :bundle_email_frequency, %i[ never every_few_hours daily weekly ],
    default: :every_few_hours, prefix: :bundle_email
  enum :push_notification_level, %i[ all_activity comments_and_mentions only_mentions ],
    default: :all_activity, prefix: :push_notifications

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
    !bundle_email_never? && !user.system? && user.active? && user.verified?
  end

  def push_notification_enabled_for?(notification)
    return true if push_notifications_all_activity?
    return true if notification.source_type == "Mention"
    return false if push_notifications_only_mentions?

    comment_notification?(notification)
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

    def comment_notification?(notification)
      notification.source_type == "Event" && notification.source.action.comment_created?
    end
end
