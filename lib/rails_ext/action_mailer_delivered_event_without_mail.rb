# With Rails.event in debug mode (config/application.rb), every delivered mail's encoded source goes to the
# log at debug level, which in SaaS mode lands in the delivery job's structured log line. That source is the
# whole message: recipients and content, and a sign-in mail's code in its subject and body. Keep the event,
# drop the message.
module ActionMailerDeliveredEventWithoutMail
  FILTERED = "[FILTERED]"

  def emit_debug_event(name, payload = nil, caller_depth: 1, **kwargs)
    if name == "action_mailer.delivered" && payload.is_a?(Hash) && payload.key?(:mail)
      payload = payload.merge(mail: FILTERED)
    end

    super(name, payload, caller_depth: caller_depth + 1, **kwargs)
  end
end

ActiveSupport.on_load(:action_mailer) do
  ActionMailer::StructuredEventSubscriber.prepend(ActionMailerDeliveredEventWithoutMail)
end
