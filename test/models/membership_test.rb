require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "send_magic_link" do
    membership = memberships(:kevin_in_37signals)

    assert_difference -> { membership.magic_links.count }, 1 do
      membership.send_magic_link
    end

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob
  end

  test "user" do
    membership = memberships(:kevin_in_37signals)

    user = membership.user

    assert_equal users(:kevin).id, user.id
    assert_equal users(:kevin).email_address, user.email_address
  end

  test "account" do
    membership = memberships(:kevin_in_37signals)

    account = membership.account

    assert_equal Account.sole.id, account.id
    assert_equal Account.sole.name, account.name
  end
end
