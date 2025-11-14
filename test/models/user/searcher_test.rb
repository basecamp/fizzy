require "test_helper"

class User::SearcherTest < ActiveSupport::TestCase
  setup do
    @user = users(:kevin)
  end

  test "remember the last search" do
    assert_difference -> { @user.search_queries.count }, +1 do
      @user.remember_search("broken")
    end

    assert_equal "broken", @user.search_queries.last.terms
  end

  test "don't duplicate repeated searches but touch the existing match" do
    search_result = @user.remember_search("broken")
    original_updated_at = search_result.updated_at

    travel_to 1.day.from_now

    assert_no_difference -> { @user.search_queries.count }, +1 do
      @user.remember_search("broken")
    end

    assert search_result.reload.updated_at > original_updated_at
  end
end
