class Notification::NativePushJob < ApplicationJob
  def perform(notification)
    Notification::Push::Native.new(notification).push
  end
end
