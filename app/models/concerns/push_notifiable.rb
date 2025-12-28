# rbs_inline: enabled

module PushNotifiable
  extend ActiveSupport::Concern

  # @type self: singleton(ActiveRecord::Base) & singleton(PushNotifiable)

  included do
    after_create_commit :push_notification_later
  end

  private
    def push_notification_later
      PushNotificationJob.perform_later(self)
    end
end
