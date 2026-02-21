class PushNotificationJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(notification)
    notification.push
  end
end
