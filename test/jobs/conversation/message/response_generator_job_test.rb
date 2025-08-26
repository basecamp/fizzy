require "test_helper"

class Conversation::Message::ResponseGeneratorJobTest < ActiveJob::TestCase
  FakeConversation = Struct.new(:responses) do
    def respond(answer, **attrs)
      self.responses << [ answer, attrs ]
    end
  end

  test "responds with an error message when something unexpected occurs" do
    message = conversation_messages(:davids_question)
    Conversation::Message.any_instance.stubs(:generate_response).raises(ArgumentError, "Oops!")

    conversation = FakeConversation.new([])
    Conversation::Message.any_instance.stubs(:conversation).returns(conversation)

    Conversation::Message::ResponseGeneratorJob.perform_now(message)

    assert_equal 1, message.conversation.responses.size
    text, _ = conversation.responses.first
    assert_match(/Something went wrong/i, text)
  end

  test "responds with an error message when all retries are exhausted" do
    message = conversation_messages(:davids_question)
    conversation = FakeConversation.new([])
    Conversation::Message.any_instance.stubs(:conversation).returns(conversation)
    Conversation::Message.any_instance.stubs(:generate_response).raises(RubyLLM::RateLimitError)

    Conversation::Message::ResponseGeneratorJob.perform_later(message)

    perform_enqueued_jobs
    assert_performed_with(job: Conversation::Message::ResponseGeneratorJob, args: [ message ])

    perform_enqueued_jobs(at: 1.minute.from_now)
    assert_performed_with(job: Conversation::Message::ResponseGeneratorJob, args: [ message ])

    perform_enqueued_jobs(at: 2.minutes.from_now)
    assert_performed_with(job: Conversation::Message::ResponseGeneratorJob, args: [ message ])

    assert_equal 1, conversation.responses.size
    text, _ = conversation.responses.first
    assert_match(/Fizzy is very busy/i, text)
  end
end
