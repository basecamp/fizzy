require "test_helper"

class Account::SedeableTest < ActiveSupport::TestCase
  setup do
    @account = Account.sole
  end

  test "setup_customer_template adds boards, cards, and comments" do
    assert_changes -> { Board.count } do
      assert_changes -> { Card.count } do
        @account.setup_customer_template
      end
    end
  end
end
