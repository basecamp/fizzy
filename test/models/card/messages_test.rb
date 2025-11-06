require "test_helper"

class Card::MessagesTest < ActiveSupport::TestCase
  test "creating a card does not create a message by default" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "New"

    assert_empty card.comments
  end
end
