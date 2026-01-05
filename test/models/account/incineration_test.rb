require "test_helper"

class Account::IncinerationTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")

    if @account.respond_to?(:subscription)
      Account.any_instance.stubs(:subscription).returns(nil)
    end
  end

  test "perform destroys account" do
    incineration = Account::Incineration.new(@account)

    assert_difference -> { Account.count }, -1 do
      incineration.perform
    end

    assert_not Account.exists?(@account.id)
  end

  test "perform cancels subscription" do
    subscription = mock("subscription")
    subscription.expects(:cancel).once
    @account.stubs(:subscription).returns(subscription)

    incineration = Account::Incineration.new(@account)
    incineration.perform
  end
end
