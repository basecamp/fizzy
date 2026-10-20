require "test_helper"

class ActionMailerDeliveredEventWithoutMailTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  CODE = "ZQ7XW3"

  setup do
    ActionMailer::Base # loads its log subscriber
    @log = StringIO.new
    @logger, ActionMailer::LogSubscriber.logger = ActionMailer::LogSubscriber.logger, ActiveSupport::Logger.new(@log)
  end

  teardown do
    ActionMailer::LogSubscriber.logger = @logger
  end

  test "a delivered mail is logged without its content and delivered with it" do
    MagicLink::Code.stubs(:generate).returns(CODE)
    events = []
    subscriber = Class.new { define_method(:emit) { |event| events << event } }.new
    Rails.event.subscribe(subscriber) { |event| event[:name] == "action_mailer.delivered" }

    assert_emails 1 do
      MagicLinkMailer.sign_in_instructions(identities(:kevin).magic_links.create!).deliver_now
    end

    assert_includes ActionMailer::Base.deliveries.last.subject, CODE, "delivery should receive the original mail"
    assert_includes ActionMailer::Base.deliveries.last.encoded, CODE
    assert_includes @log.string, "Delivered mail"
    assert_no_match CODE, @log.string
    assert_equal [ ActionMailerDeliveredEventWithoutMail::FILTERED ], events.map { |event| event[:payload][:mail] }
  ensure
    Rails.event.unsubscribe(subscriber)
  end

  test "the filter runs ahead of every other delivery consumer from boot" do
    listeners = ActiveSupport::Notifications.notifier.listeners_for("deliver.action_mailer")

    assert_same ActionMailerDeliveredEventWithoutMail::SUBSCRIBER, listeners.first
    assert listeners.many?, "Rails' own mail subscribers should follow it"
  end
end
