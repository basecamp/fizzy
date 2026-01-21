class Notification::WebPushJob < ApplicationJob
  def perform(notification)
    Notification::PushTarget::Web.new(notification).push
  end
end
