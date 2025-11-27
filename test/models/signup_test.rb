require "test_helper"

class SignupTest < ActiveSupport::TestCase
  test "#create_identity" do
    signup = Signup.new(email_address: "brian@example.com")

    assert_difference -> { Identity.count }, 1 do
      assert_difference -> { MagicLink.count }, 1 do
        assert signup.create_identity
      end
    end

    assert_empty signup.errors
    assert signup.identity
    assert signup.identity.persisted?

    signup_existing = Signup.new(email_address: "brian@example.com")

    assert_no_difference -> { Identity.count } do
      assert_difference -> { MagicLink.count }, 1 do
        assert signup_existing.create_identity, "Should send magic link for existing identity"
      end
    end

    signup_invalid = Signup.new(email_address: "")
    assert_raises do
      signup_invalid.create_identity
    end
  end

  test "#complete" do
    Account.any_instance.expects(:setup_customer_template).once

    Current.without_account do
      signup = Signup.new(full_name: "Kevin", identity: identities(:kevin))

      assert signup.complete

      assert signup.account
      assert signup.user
      assert_equal "Kevin", signup.user.name

      signup_invalid = Signup.new(
        full_name: "",
        identity: identities(:kevin)
      )
      assert_not signup_invalid.complete
      assert_not_empty signup_invalid.errors[:full_name]
    end
  end
end
