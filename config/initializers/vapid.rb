Rails.application.configure do
  config.x.vapid.private_key = ENV["VAPID_PRIVATE_KEY"]
  config.x.vapid.public_key = ENV["VAPID_PUBLIC_KEY"]
  config.x.vapid.subject = ENV.fetch("VAPID_SUBJECT") { config.x.vapid.subject || "mailto:support@fizzy.do" }
end
