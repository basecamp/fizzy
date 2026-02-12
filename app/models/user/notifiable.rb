module User::Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, dependent: :destroy
    has_many :notification_bundles, class_name: "Notification::Bundle", dependent: :destroy

    generates_token_for :unsubscribe, expires_in: 1.month
  end

  def bundle(notification)
    with_lock do
      find_or_create_bundle_for(notification)
    end
  end

  private
    def find_or_create_bundle_for(notification)
      find_bundle_for(notification) || expand_pending_bundle_for(notification) || create_bundle_for(notification)
    end

    def find_bundle_for(notification)
      notification_bundles.pending.containing(notification).last
    end

    def expand_pending_bundle_for(notification)
      pending = notification_bundles.pending.last
      if pending.present? && notification.updated_at < pending.starts_at
        pending.update!(starts_at: notification.updated_at) # expand the window to include this notification
      end
    end

    def create_bundle_for(notification)
      notification_bundles.create!(starts_at: notification.updated_at)
    end
end
