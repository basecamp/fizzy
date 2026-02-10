class Notification::PushJob < ApplicationJob
  def perform(notification)
    notification.push
  end
end
