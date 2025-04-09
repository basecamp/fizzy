require "test_helper"

class ClosureReasonsTest < ActiveSupport::TestCase
  test "create defaults closure reasons on creation" do
    account = Account.create! name: "Rails"
    assert_equal Account::ClosureReasons::DEFAULT_LABELS, account.closure_reasons.pluck(:label)
  end
end
