require "test_helper"

class TimeSlotTest < ActiveSupport::TestCase
  test "for latertoday" do
    travel_to Time.zone.local(2023, 1, 1, 10, 0, 0) do
      assert_equal Time.zone.local(2023, 1, 1, 18, 0, 0), TimeSlot.for("latertoday")
    end
  end

  test "for tomorrow" do
    travel_to Time.zone.local(2023, 1, 1, 10, 0, 0) do
      assert_equal Time.zone.local(2023, 1, 2, 8, 0, 0), TimeSlot.for("tomorrow")
    end
  end

  test "for thisweekend" do
    travel_to Time.zone.local(2023, 1, 1, 10, 0, 0) do
      assert_equal Time.zone.local(2023, 1, 7, 8, 0, 0), TimeSlot.for("thisweekend")
    end

    travel_to Time.zone.local(2023, 1, 2, 10, 0, 0) do
      assert_equal Time.zone.local(2023, 1, 7, 8, 0, 0), TimeSlot.for("thisweekend")
    end
  end

  test "for nextweek" do
    travel_to Time.zone.local(2023, 1, 1, 10, 0, 0) do
      assert_equal Time.zone.local(2023, 1, 2, 8, 0, 0), TimeSlot.for("nextweek")
    end

    travel_to Time.zone.local(2023, 1, 2, 10, 0, 0) do
      assert_equal Time.zone.local(2023, 1, 9, 8, 0, 0), TimeSlot.for("nextweek")
    end
  end

  test "for surprise" do
    travel_to Time.zone.local(2023, 1, 1, 10, 0, 0) do
      result = TimeSlot.for("surprise")
      assert result >= Time.zone.local(2023, 1, 3, 8, 0, 0)
      assert result <= Time.zone.local(2023, 1, 15, 8, 0, 0)
      assert_equal 8, result.hour
    end
  end
end
