class PushNotificationJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(notification)
    NotificationPusher.new(notification).push
  end
end
