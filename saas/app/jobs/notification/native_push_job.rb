class Notification::NativePushJob < ApplicationJob
  def perform(notification)
    Notification::PushTarget::Native.new(notification).push
  end
end
