Rails.application.config.to_prepare do
  Notification.register_push_target(:web)
end
