require "test_helper"

class Fizzy::Saas::SignupTest < ActiveSupport::TestCase
  test "#complete creates queenbee account and uses its id as tenant" do
    queenbee_account = mock("queenbee_account")
    queenbee_account.stubs(:id).returns(123456)

    Queenbee::Remote::Account.expects(:create!).once.returns(queenbee_account)
    Account.any_instance.expects(:setup_customer_template).once

    Current.without_account do
      assert_changes -> { Account.count }, +1 do
        sequence_value_before = Account::ExternalIdSequence.value

        signup = Signup.new(
          full_name: "Kevin",
          identity: identities(:kevin)
        )

        assert signup.complete

        assert signup.account
        assert_equal 123456, signup.account.external_account_id
        assert_equal sequence_value_before, Account::ExternalIdSequence.value
      end
    end
  end

  test "#complete calls cancel on queenbee account when account creation fails" do
    queenbee_account = mock("queenbee_account")
    queenbee_account.stubs(:id).returns(789012)
    queenbee_account.expects(:cancel).once

    Queenbee::Remote::Account.expects(:create!).once.returns(queenbee_account)
    Account.any_instance.stubs(:setup_customer_template).raises(StandardError.new("Account setup failed"))

    Current.without_account do
      signup = Signup.new(
        full_name: "Kevin",
        identity: identities(:kevin)
      )

      assert_not signup.complete
      assert_includes signup.errors[:base], "Something went wrong, and we couldn't create your account. Please give it another try."
    end
  end
end
