class ApplicationPushNotification < ActionPushNative::Notification
  queue_as :default
  self.enabled = !Rails.env.local? || ENV["ENABLE_NATIVE_PUSH"] == "true"
end
