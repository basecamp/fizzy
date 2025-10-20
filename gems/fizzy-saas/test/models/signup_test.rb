require "test_helper"

class SignupTest < ActiveSupport::TestCase
  setup do
    @starting_tenants = ApplicationRecord.tenants
  end

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
    assert_not signup_invalid.create_identity, "Should fail with invalid email"
    assert_not_empty signup_invalid.errors[:email_address], "Should have validation error for email_address"
  end

  test "#complete" do
    Account.any_instance.expects(:setup_basic_template).once

    signup = Signup.new(
      full_name: "Kevin",
      company_name: "37signals",
      email_address: "kevin@example.com",
      identity: identities(:kevin)
    )

    assert signup.complete, signup.errors.full_messages.to_sentence(words_connector: ". ")

    assert signup.tenant
    assert signup.account
    assert signup.user
    assert_equal "Kevin", signup.user.name
    assert_equal "37signals", signup.account.name

    signup_invalid = Signup.new(
      full_name: "",
      company_name: "37signals",
      email_address: "kevin@example.com",
      identity: identities(:kevin)
    )
    assert_not signup_invalid.complete, "Complete should fail with invalid params"
    assert_not_empty signup_invalid.errors[:full_name], "Should have validation error for full_name"
  end
end
