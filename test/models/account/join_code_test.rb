require "test_helper"

class Account::JoinCodeTest < ActiveSupport::TestCase
  test "generate code" do
    join_code = Account::JoinCode.create!

    assert join_code.code.present?

    parts = join_code.code.split("-")
    assert_equal 3, parts.count
  end

  test "redeem" do
    join_code = account_join_codes(:sole)

    assert_difference -> { join_code.reload.usage_count }, 1 do
      join_code.redeem
    end
  end

  test "reset" do
    join_code = account_join_codes(:sole)
    original_code = join_code.code

    join_code.reset

    assert_not_equal original_code, join_code.code
    assert_equal 0, join_code.usage_count
  end
end
