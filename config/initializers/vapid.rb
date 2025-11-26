Rails.application.configure do
  config.x.vapid.private_key = ENV["VAPID_PRIVATE_KEY"]
  config.x.vapid.public_key = ENV["VAPID_PUBLIC_KEY"]
end
