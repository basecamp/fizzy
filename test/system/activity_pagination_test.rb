require "application_system_test_case"

class ActivityPaginationTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:david))
  end

  test "scrolling back to a loaded day does not load it again" do
    push_activity_below_the_fold
    link = first(".day-timeline-pagination-link", visible: :all)
    frame_selector = "turbo-frame##{link[:"data-frame"]}"

    scroll_into_view link
    assert_selector frame_selector, count: 1, visible: :all

    page.execute_script("window.scrollTo(0, 0)")
    wait_for_intersection_callbacks
    scroll_into_view link
    wait_for_intersection_callbacks

    assert_selector frame_selector, count: 1, visible: :all
  end

  private
    def push_activity_below_the_fold
      page.execute_script(<<~JS)
        document.getElementById("activity").insertAdjacentHTML("beforebegin", `<div style="block-size: 3000px"></div>`)
      JS
    end

    def scroll_into_view(element)
      page.execute_script("arguments[0].scrollIntoView()", element)
    end

    def wait_for_intersection_callbacks
      page.evaluate_async_script(<<~JS)
        const done = arguments[0]
        requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(done, 0)))
      JS
    end
end
