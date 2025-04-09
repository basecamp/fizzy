require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get cards_url
    assert_response :success
  end

  test "filtered index" do
    get cards_url(filters(:jz_assignments).as_params.merge(term: "haggis"))
    assert_response :success
  end

  test "create" do
    assert_difference "Card.count", 1 do
      post collection_cards_url(collections(:writebook))
    end
    assert_redirected_to collection_card_url(collections(:writebook), Card.last)
  end

  test "show" do
    get collection_card_url(collections(:writebook), cards(:logo))
    assert_response :success
  end

  test "edit" do
    get edit_collection_card_url(collections(:writebook), cards(:logo))
    assert_response :success
  end

  test "update" do
    patch collection_card_url(collections(:writebook), cards(:logo)), params: {
      card: {
        title: "Logo needs to change",
        color: "#000000",
        due_on: 1.week.from_now,
        image: fixture_file_upload("moon.jpg", "image/jpeg"),
        draft_comment: "Something more in-depth",
        tag_ids: [ tags(:mobile).id ] } }
    assert_redirected_to collection_card_url(collections(:writebook), cards(:logo))

    card = cards(:logo).reload
    assert_equal "Logo needs to change", card.title
    assert_equal "#000000", card.color
    assert_equal 1.week.from_now.to_date, card.due_on
    assert_equal "moon.jpg", card.image.filename.to_s
    assert_equal [ tags(:mobile) ], card.tags

    assert_equal "Something more in-depth", card.messages.comments.first.comment.body_plain_text.strip
  end

  test "users can only see cards in collections they have access to" do
    get collection_card_url(collections(:writebook), cards(:logo))
    assert_response :success

    collections(:writebook).update! all_access: false
    collections(:writebook).accesses.revoke_from users(:kevin)
    get collection_card_url(collections(:writebook), cards(:logo))
    assert_response :not_found
  end
end
