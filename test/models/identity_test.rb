require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "send_magic_link" do
    identity = identities(:david)

    assert_emails 1 do
      magic_link = identity.send_magic_link
      assert_not_nil magic_link
      assert_equal identity, magic_link.identity
    end
  end

  test "email address format validation" do
    invalid_emails = [
      "sam smith@example.com",       # space in local part
      "@example.com",                # missing local part
      "test@",                       # missing domain
      "test",                        # missing @ and domain
      "<script>@example.com",        # angle brackets
      "test@example.com\nX-Inject:" # newline (header injection attempt)
    ]

    invalid_emails.each do |email|
      identity = Identity.new(email_address: email)
      assert_not identity.valid?, "expected #{email.inspect} to be invalid"
      assert identity.errors[:email_address].any?, "expected error on email_address for #{email.inspect}"
    end
  end

  test "join" do
    identity = identities(:david)
    account = accounts(:initech)

    Current.without_account do
      assert_difference "User.count", 1 do
        identity.join(account)
      end

      user = account.users.find_by!(identity: identity)

      assert_not_nil user
      assert_equal identity, user.identity
      assert_equal identity.email_address, user.name
    end
  end

  test "destroy deactivates users before nullifying identity" do
    identity = identities(:kevin)
    user = users(:kevin)

    assert_predicate user, :active?
    assert_predicate user.accesses, :any?

    identity.destroy!
    user.reload

    assert_nil user.identity_id, "identity should be nullified"
    assert_not_predicate user, :active?
    assert_empty user.accesses, "user accesses should be removed"
  end
end
