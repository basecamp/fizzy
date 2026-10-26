require "test_helper"

class Account::JoinCodeTest < ActiveSupport::TestCase
  test "generate code" do
    join_code = Account::JoinCode.create!(account: Current.account)

    assert join_code.code.present?

    parts = join_code.code.split("-")
    assert_equal 3, parts.count
  end

  test "redeem_if increments usage_count when block returns true" do
    join_code = account_join_codes(:"37s")

    assert_difference -> { join_code.reload.usage_count }, +1 do
      join_code.redeem_if { true }
    end
  end

  test "redeem_if does not increment usage_count when block returns false" do
    join_code = account_join_codes(:"37s")

    assert_no_difference -> { join_code.reload.usage_count } do
      join_code.redeem_if { false }
    end
  end

  test "redeem_if refuses a code reset after it was found" do
    join_code = account_join_codes(:"37s")
    Account::JoinCode.find(join_code.id).reset
    joined = false

    assert_no_difference -> { Account::JoinCode.find(join_code.id).usage_count } do
      join_code.redeem_if { joined = true }
    end
    assert_not joined
  end

  test "reset" do
    join_code = account_join_codes(:"37s")
    original_code = join_code.code

    join_code.reset

    assert_not_equal original_code, join_code.code
    assert_equal 0, join_code.usage_count
  end
end
