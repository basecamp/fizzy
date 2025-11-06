require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    travel_to Time.utc(2025, 1, 22, 17, 30, 0)

    events(:layout_assignment_jz).update!(created_at: Time.current.beginning_of_day + 8.hours)
  end

  test "index" do
    get events_path

    assert_select "div.events__time-block[style='grid-area: 17/2']" do
      assert_select "strong", text: /assigned JZ to Layout is broken/
    end
  end

  test "index with a specific timezone" do
    cookies[:timezone] = "America/New_York"

    get events_path

    assert_select "div.events__time-block[style='grid-area: 22/2']" do
      assert_select "strong", text: /assigned JZ to Layout is broken/
    end
  end

  test "only displays events from filtered boards" do
    get events_path(board_ids: [ boards(:writebook).id ])
    assert_response :success

    events_shown = css_select(".event").count
    assert events_shown > 0, "Should show some events"

    css_select(".event").each do |event|
      assert_includes event.text, boards(:writebook).name
    end
  end
end
