require "test_helper"

class Bubble::TaggableTest < ActiveSupport::TestCase
  setup do
    @bubble = bubbles(:logo)
  end

  test "toggle tag" do
    assert_difference -> { @bubble.tags.count }, 1 do
      @bubble.toggle_tag_with "ruby"
    end

    assert_equal "ruby", @bubble.tags.last.title

    assert_difference -> { @bubble.tags.count }, -1 do
      @bubble.toggle_tag_with "ruby"
    end
  end
end
