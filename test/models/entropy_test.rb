require "test_helper"

class Entropy::Test < ActiveSupport::TestCase
  test "touch cards when entropy changes for board" do
    assert_changes -> { boards(:writebook).cards.first.updated_at } do
      boards(:writebook).entropy.update!(auto_postpone_period: 7.days)
    end
  end

  test "default auto-postpone period is included in allowed periods" do
    assert_includes Entropy::AUTO_POSTPONE_PERIODS_IN_DAYS, Entropy::DEFAULT_AUTO_POSTPONE_PERIOD_IN_DAYS
  end

  test "board entropy falls back to account entropy period when value is invalid" do
    board = boards(:writebook)
    board.entropy.update_column(:auto_postpone_period, 999.days.to_i)

    assert_equal Current.account.entropy.auto_postpone_period_in_days, board.entropy.auto_postpone_period_in_days
  end

  test "touch cards when entropy changes for account container" do
    account = Current.account

    assert_changes -> { account.cards.first.updated_at } do
      boards(:writebook).entropy.update!(auto_postpone_period: 7.days)
    end
  end
end
