require "test_helper"

class Events::DayTimeline::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show added column" do
    get events_day_timeline_column_path("added")
    assert_response :success
    assert_select "h1", text: /Added/
  end

  test "show updated column" do
    get events_day_timeline_column_path("updated")
    assert_response :success
    assert_select "h1", text: /Updated/
  end

  test "show closed column" do
    get events_day_timeline_column_path("closed")
    assert_response :success
    assert_select "h1", text: /Done/
  end

  test "show returns not found for invalid column" do
    get events_day_timeline_column_path("invalid")
    assert_response :not_found
  end

  test "show returns not found for an unparseable day param" do
    get events_day_timeline_column_path("added", day: "garbage")
    assert_response :not_found
  end
end
