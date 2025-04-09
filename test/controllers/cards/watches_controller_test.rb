require "test_helper"

class Bubbles::WatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    bubbles(:logo).unwatch_by users(:kevin)

    assert_changes -> { bubbles(:logo).watched_by?(users(:kevin)) }, from: false, to: true do
      post bubble_watch_path(bubbles(:logo))
    end

    assert_redirected_to bubble_watch_path(bubbles(:logo))
  end

  test "destroy" do
    bubbles(:logo).watch_by users(:kevin)

    assert_changes -> { bubbles(:logo).watched_by?(users(:kevin)) }, from: true, to: false do
      delete bubble_watch_path(bubbles(:logo))
    end

    assert_redirected_to bubble_watch_path(bubbles(:logo))
  end
end
