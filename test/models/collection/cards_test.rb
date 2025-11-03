require "test_helper"

class Collection::CardsTest < ActiveSupport::TestCase
  test "touch cards when the name changes" do
    collection = collections(:writebook)

    assert_changes -> { collection.cards.first.updated_at } do
      collection.update!(name: "New Name")
    end

    assert_no_changes -> { collection.cards.first.updated_at } do
      collection.update!(updated_at: 1.hour.from_now)
    end
  end
end
