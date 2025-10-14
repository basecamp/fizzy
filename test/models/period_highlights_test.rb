require "test_helper"

class PeriodHighlightTest < ActiveSupport::TestCase
  include VcrTestHelper

  setup do
    @user = users(:david)
  end

  test "generate period highlights" do
    period_highlights = assert_difference -> { PeriodHighlights.count }, 1 do
      PeriodHighlights.create_or_find_for(@user.collections, starts_at: 1.month.ago, duration: 2.months)
    end

    assert_match /logo/i, period_highlights.to_html
  end

  test "don't generate highlights for existing periods" do
    new_period_highlights = PeriodHighlights.create_or_find_for(@user.collections, starts_at: 1.month.ago, duration: 2.months)

    existing_period_highlights = assert_no_difference -> { PeriodHighlights.count } do
      PeriodHighlights.create_or_find_for(@user.collections, starts_at: 1.month.ago, duration: 2.months)
    end

    assert_equal new_period_highlights, existing_period_highlights
  end
end
