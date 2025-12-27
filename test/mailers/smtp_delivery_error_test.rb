require "test_helper"

class SmtpDeliveryErrorTest < ActionMailer::TestCase
  class TestMailer < ApplicationMailer
    def smtp_syntax_error(message)
      raise Net::SMTPSyntaxError, Net::SMTP::Response.parse(message)
    end

    def smtp_fatal_error(message)
      raise Net::SMTPFatalError, Net::SMTP::Response.parse(message)
    end

    def ephemeral_retry
      self.class.goes_boom_once
    end

    def self.goes_boom_once
      # Stubbed in test to raise exception once
    end
  end
  tests TestMailer

  test "deliver_later ignores bad recipient addresses" do
    assert_nothing_raised do
      perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        TestMailer.smtp_syntax_error("501 5.1.3 Bad recipient address syntax\n").deliver_later
      end
    end
  end

  test "deliver_later ignores rejected recipient addresses" do
    assert_nothing_raised do
      perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        TestMailer.smtp_fatal_error("550 5.1.1 fooaddress: Recipient address rejected: User unknown in local recipient table\n").deliver_later
      end
    end
  end

  test "deliver_later re-raises other SMTP syntax errors" do
    perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      assert_raises Net::SMTPSyntaxError do
        TestMailer.smtp_syntax_error("not a recipient address error").deliver_later
      end
    end
  end


  [ Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy.new(Net::SMTP::Response.parse("4xx Server Busy")) ].each do |exception|
    test "deliver_later retries temporary #{exception}" do
      TestMailer.stubs(:goes_boom_once).raises(exception).then.returns(nil)

      perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        assert_nothing_raised do
          TestMailer.ephemeral_retry.deliver_later
        end
      end
    end
  end
end
