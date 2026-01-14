class ApplicationPushNotification < ActionPushNative::Notification
  queue_as :default
  self.enabled = !Rails.env.local?
end
