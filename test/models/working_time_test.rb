require "test_helper"

class WorkingTimeTest < ActiveSupport::TestCase
  test "counts time within a working day" do
    start_time = time_zone.local(2026, 7, 15, 10, 15)
    end_time = time_zone.local(2026, 7, 15, 12, 45)

    assert_equal 150, WorkingTime.minutes_between(start_time, end_time, time_zone: time_zone)
  end

  test "only counts the configured working-day window" do
    start_time = time_zone.local(2026, 7, 15, 7)
    end_time = time_zone.local(2026, 7, 15, 20)

    assert_equal 540, WorkingTime.minutes_between(start_time, end_time, time_zone: time_zone)
  end

  test "excludes Saturday and Sunday" do
    start_time = time_zone.local(2026, 7, 17, 17, 30)
    end_time = time_zone.local(2026, 7, 20, 10, 30)

    assert_equal 120, WorkingTime.minutes_between(start_time, end_time, time_zone: time_zone)
  end

  test "returns zero for an inverted interval" do
    start_time = time_zone.local(2026, 7, 15, 12)

    assert_equal 0, WorkingTime.minutes_between(start_time, start_time - 1.hour, time_zone: time_zone)
  end

  private
    def time_zone
      @time_zone ||= ActiveSupport::TimeZone["Asia/Kolkata"]
    end
end
