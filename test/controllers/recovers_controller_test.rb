require "test_helper"

class Cards::RecoversControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :jz
  end

  test "create" do
    abandoned_card = collections(:writebook).cards.create! creator: users(:kevin)
    abandoned_card.update!(title: "An edited title")
    unsaved_card = collections(:writebook).cards.create! creator: users(:kevin)

    post card_recover_url(unsaved_card)

    assert_redirected_to abandoned_card
    assert_equal [ abandoned_card ], Card.creating
  end
end
