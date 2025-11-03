require "test_helper"

class Entropy::Test < ActiveSupport::TestCase
  test "touch cards when entropy changes for collection" do
    assert_changes -> { collections(:writebook).cards.first.updated_at } do
      collections(:writebook).entropy.update!(auto_postpone_period: 15.days)
    end
  end

  test "touch cards when entropy changes for account container" do
    account = Account.sole

    assert_changes -> { account.cards.first.updated_at } do
      collections(:writebook).entropy.update!(auto_postpone_period: 15.days)
    end
  end
end
