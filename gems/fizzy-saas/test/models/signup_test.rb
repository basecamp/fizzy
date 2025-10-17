require "test_helper"

class SignupTest < ActiveSupport::TestCase
  setup do
    @starting_tenants = ApplicationRecord.tenants
  end

  test "#create_account" do
    Account.any_instance.expects(:setup_basic_template).once

    signup = Signup.new(email_address: "brian@example.com")

    assert_difference -> { Membership.count }, 1 do
      assert_difference -> { MagicLink.count }, 1 do
        assert signup.create_account, signup.errors.full_messages.to_sentence(words_connector: ". ")
      end
    end

    assert_empty signup.errors
    assert signup.tenant
    assert_includes ApplicationRecord.tenants, signup.tenant
    assert signup.account
    assert signup.account.persisted?
    assert signup.user
    assert signup.user.persisted?

    signup_existing = Signup.new(email_address: "brian@example.com")

    assert_no_difference -> { Membership.count } do
      assert_difference -> { MagicLink.count }, 1 do
        assert signup_existing.create_account, "Should send magic link for existing membership"
      end
    end

    signup_invalid = Signup.new(email_address: "")
    assert_not signup_invalid.create_account, "Should fail with invalid email"
    assert_not_empty signup_invalid.errors[:email_address], "Should have validation error for email_address"

    Queenbee::Remote::Account.stubs(:create!).raises(RuntimeError, "Invalid account data")
    signup_error = Signup.new(email_address: "error@example.com")

    assert_not signup_error.create_account, "Should fail when error occurs"
    assert_not_empty signup_error.errors[:base], "Should have base error"
    assert_nil signup_error.tenant
    assert_nil signup_error.account
    assert_nil signup_error.user
  end

  test "#complete" do
    signup = Signup.new(
      tenant: ApplicationRecord.current_tenant,
      user: users(:kevin),
      full_name: "Kevin Systrom",
      company_name: "37signals"
    )

    assert signup.complete, signup.errors.full_messages.to_sentence(words_connector: ". ")

    assert_equal "Kevin Systrom", users(:kevin).reload.name, "User name should be updated"
    assert_equal "37signals", Account.sole.reload.name, "Account name should be updated"
    assert_equal "37signals", users(:kevin).membership.reload.account_name, "Membership account name should be updated"

    signup.full_name = ""
    assert_not signup.complete, "Complete should fail with invalid params"
    assert_not_empty signup.errors[:full_name], "Should have validation error for full_name"
  end
end
