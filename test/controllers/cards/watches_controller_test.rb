require "test_helper"

class Cards::WatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    cards(:logo).unwatch_by users(:kevin)

    assert_changes -> { cards(:logo).watched_by?(users(:kevin)) }, from: false, to: true do
      post card_watch_path(cards(:logo))
    end
  end

  test "destroy" do
    cards(:logo).watch_by users(:kevin)

    assert_changes -> { cards(:logo).watched_by?(users(:kevin)) }, from: true, to: false do
      delete card_watch_path(cards(:logo))
    end
  end
end
