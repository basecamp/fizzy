class Conversation::Message::ResponseGeneratorJob < ApplicationJob
  discard_on StandardError do |job, error|
    Rails.error.report(error, severity: :error)

    if conversation = job.arguments.first.try(:conversation)
      conversation.respond("Something went wrong. Please try again in a moment.")
    end
  end

  retry_on RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError, wait: 2.seconds, attempts: 3 do |job, error|
    message = job.arguments.first
    message.conversation.respond("Fizzy is very busy at the moment. Please try again in a minute.")
  end

  def perform(message)
    message.generate_response
  end
end
