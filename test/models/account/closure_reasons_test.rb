require "test_helper"

class PopReasonsTest < ActiveSupport::TestCase
  test "create defaults pop reasons on creation" do
    account = Account.create! name: "Rails"
    assert_equal Account::PopReasons::DEFAULT_LABELS, account.pop_reasons.pluck(:label)
  end
end
