# With Rails.event in debug mode (config/application.rb), every delivered mail's encoded source goes to the
# log at debug level, which in SaaS mode lands in the delivery job's structured log line. That source is the
# whole message: recipients and content, and a sign-in mail's code in its subject and body.
#
# Prepended, so it runs before Rails' structured event and every other deliver.action_mailer consumer. The
# notification finishes after delivery, and delivery works from the mail object, not this encoded copy.
module ActionMailerDeliveredEventWithoutMail
  FILTERED = "[FILTERED]"

  SUBSCRIBER = ActiveSupport::Notifications.subscribe("deliver.action_mailer", prepend: true) do |event|
    event.payload[:mail] = FILTERED if event.payload.key?(:mail)
  end
end
