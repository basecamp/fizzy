require "test_helper"

class Card::TaggableTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
  end

  test "toggle tag" do
    assert_difference -> { @card.tags.count }, 1 do
      @card.toggle_tag_with "ruby"
    end

    assert_equal "ruby", @card.tags.last.title

    assert_difference -> { @card.tags.count }, -1 do
      @card.toggle_tag_with "ruby"
    end
  end
end
