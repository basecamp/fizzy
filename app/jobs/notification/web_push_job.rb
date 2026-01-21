class Notification::WebPushJob < ApplicationJob
  def perform(notification)
    Notification::Push::Web.new(notification).push
  end
end
