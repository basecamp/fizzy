require "test_helper"

# British Columbia, Alberta and Manitoba stop changing clocks in November 2026 (IANA tzdata 2026b, 2026c, 2026e).
# Zone data comes from the tzinfo-data gem, so it doesn't depend on how old the image's tzdata package is.
class CanadianPermanentTimeTest < ActiveSupport::TestCase
  test "zone data comes from the bundled tzinfo-data gem, not the system's zoneinfo" do
    assert_kind_of TZInfo::DataSources::RubyDataSource, TZInfo::DataSource.get
  end

  { "Pacific Time (Canada)" => -7, "Alberta" => -6, "Manitoba" => -5 }.each do |zone_name, hours|
    test "#{zone_name} keeps UTC#{hours} before and after November 1, 2026" do
      zone = ActiveSupport::TimeZone[zone_name]

      assert_equal hours.hours, zone.parse("2026-10-15 12:00").utc_offset
      assert_equal hours.hours, zone.parse("2026-11-15 12:00").utc_offset
      assert_equal hours.hours, zone.parse("2027-01-15 12:00").utc_offset
    end
  end
end
