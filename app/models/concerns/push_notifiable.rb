module PushNotifiable
  extend ActiveSupport::Concern

  included do
    after_create_commit :push_notification_later
    after_update_commit :push_notification_later, if: :source_id_previously_changed?
  end

  private
    def push_notification_later
      PushNotificationJob.perform_later(self)
    end
end
