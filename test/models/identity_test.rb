require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "send_magic_link" do
    identity = identities(:kevin)

    assert_difference -> { identity.magic_links.count }, 1 do
      identity.send_magic_link
    end

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob
  end
end
