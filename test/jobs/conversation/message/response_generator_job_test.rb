require "test_helper"

class Conversation::Message::ResponseGeneratorJobTest < ActiveJob::TestCase
  test "responds with an error message when something unexpected occurs" do
    message = conversation_messages(:davids_question)
    conversation = message.conversation
    Conversation::Message.any_instance.stubs(:generate_response).raises(ArgumentError, "Oops!")

    assert_error_reported ArgumentError do
      assert_changes -> { conversation.messages.count }, +1 do
        Conversation::Message::ResponseGeneratorJob.perform_now(message)
      end
    end

    last_message = conversation.messages.ordered.last
    assert last_message.assistant?
    assert_match(/Something went wrong/i, last_message.content.to_plain_text)
  end

  test "responds with an error message when all retries are exhausted" do
    message = conversation_messages(:davids_question)
    conversation = message.conversation
    Conversation::Message.any_instance.stubs(:generate_response).raises(RubyLLM::RateLimitError)

    assert_no_error_reported do
      assert_changes -> { conversation.messages.count }, +1 do
        Conversation::Message::ResponseGeneratorJob.perform_later(message)

        perform_enqueued_jobs
        assert_performed_with(job: Conversation::Message::ResponseGeneratorJob, args: [ message ])

        perform_enqueued_jobs(at: 1.minute.from_now)
        assert_performed_with(job: Conversation::Message::ResponseGeneratorJob, args: [ message ])

        perform_enqueued_jobs(at: 2.minutes.from_now)
        assert_performed_with(job: Conversation::Message::ResponseGeneratorJob, args: [ message ])
      end
    end

    last_message = conversation.messages.ordered.last
    assert last_message.assistant?
    assert_match(/Fizzy is very busy/i, last_message.content.to_plain_text)
  end
end
