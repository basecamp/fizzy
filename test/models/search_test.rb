require "test_helper"

class SearchTest < ActiveSupport::TestCase
  setup do
    Card.all.each(&:reindex)
    Comment.all.each(&:reindex)

    @user = users(:kevin)
  end

  test "search cards and comments" do
    assert @user.search("layout").find { it.card == cards(:layout) }
    assert @user.search("overflowing").find { it.comment == comments(:layout_overflowing_david) }
  end

  test "don't include innaccessible" do
    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from(@user)

    assert_not @user.search("layout").find { it.card == cards(:layout) }
    assert_not @user.search("overflowing").find { it.comment == comments(:layout_overflowing_david) }
  end
end
