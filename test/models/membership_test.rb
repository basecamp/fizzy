require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "send_magic_link" do
    membership = memberships(:kevin_in_37signals)

    assert_difference -> { membership.identity.magic_links.count }, 1 do
      membership.identity.send_magic_link
    end

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob
  end
end
