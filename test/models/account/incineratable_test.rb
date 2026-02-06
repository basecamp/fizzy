require "test_helper"

class Account::IncineratableTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")
    @user = users(:david)
  end

  test "incinerate destroys account" do
    assert_difference -> { Account.count }, -1 do
      @account.incinerate
    end

    assert_not Account.exists?(@account.id)
  end

  test "due_for_incineration finds old cancellations" do
    @account.cancel(initiated_by: @user)

    @account.cancellation.update!(created_at: 31.days.ago)
    assert_equal [ @account ], Account.due_for_incineration

    @account.cancellation.update!(created_at: 29.days.ago)
    assert Account.due_for_incineration.empty?
  end
end
