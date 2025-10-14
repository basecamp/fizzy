require "test_helper"

class User::HighlightsTest < ActiveSupport::TestCase
  include VcrTestHelper

  setup do
    @user = users(:david)
    travel_to [ Time.current, 1.day.ago ].find { |d| !d.sunday? }
    Current.session = sessions(:david)
  end

  test "generate weekly highlights" do
    stub_const(PeriodHighlights::Period, :MIN_EVENTS_TO_BE_INTERESTING, 3) do
      period_highlights = assert_difference -> { PeriodHighlights.count }, 1 do
        @user.generate_weekly_highlights
      end

      assert_match /logo/i, period_highlights.to_html
    end
  end

  test "don't generate highlights for existing periods" do
    stub_const(PeriodHighlights::Period, :MIN_EVENTS_TO_BE_INTERESTING, 3) do
      new_period_highlights = @user.generate_weekly_highlights
      assert_not_nil new_period_highlights

      existing_period_highlights = assert_no_difference -> { PeriodHighlights.count } do
        @user.generate_weekly_highlights
      end

      assert_equal new_period_highlights, existing_period_highlights
    end
  end

  test "periods respect user timezone for week boundaries" do
    @user.settings.update!(timezone_name: "America/New_York")

    # Sunday Jan 7, 2024 at 2am EST (7am UTC) - this is Sunday in NYC
    sunday_in_nyc = Time.zone.parse("2024-01-07 07:00:00 UTC")

    # Saturday Jan 6, 2024 at 11pm EST (Jan 7 4am UTC) - still Saturday in NYC but Sunday in UTC
    saturday_in_nyc = Time.zone.parse("2024-01-07 04:00:00 UTC")

    # Event on Saturday evening in NYC (but Sunday in UTC)
    saturday_event = travel_to(saturday_in_nyc) { cards(:logo).track_event("Saturday event") }

    # Events throughout the week starting Sunday in NYC
    7.times do |i|
      travel_to(sunday_in_nyc + i.days) { cards(:logo).track_event("Event #{i}") }
    end

    wednesday = sunday_in_nyc + 3.days

    # The period should start at Sunday in NYC timezone
    period_start = wednesday.in_time_zone("America/New_York").beginning_of_week(:sunday)
    period = PeriodHighlights::Period.new(@user.collections, starts_at: period_start, duration: 1.week)

    # The Saturday event should NOT be included (it's in the previous week in NYC time)
    assert_not_includes period.events, saturday_event

    # Should include 7 events from the current week
    assert_equal 7, period.events.count
  end
end
