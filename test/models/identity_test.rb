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

  test "staff?" do
    assert Identity.new(email_address: "test@37signals.com").staff?
    assert Identity.new(email_address: "test@basecamp.com").staff?
    assert_not Identity.new(email_address: "test@example.com").staff?
  end
end
