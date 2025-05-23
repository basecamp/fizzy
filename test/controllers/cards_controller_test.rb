require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get cards_path
    assert_response :success
  end

  test "filtered index" do
    get cards_path(filters(:jz_assignments).as_params.merge(term: "haggis"))
    assert_response :success
  end

  test "create" do
    assert_difference "Card.count", 1 do
      post collection_cards_path(collections(:writebook))
    end
    assert_redirected_to collection_card_path(collections(:writebook), Card.last)
  end

  test "show" do
    get collection_card_path(collections(:writebook), cards(:logo))
    assert_response :success
  end

  test "edit" do
    get edit_collection_card_path(collections(:writebook), cards(:logo))
    assert_response :success
  end

  test "update" do
    patch collection_card_path(collections(:writebook), cards(:logo)), params: {
      card: {
        title: "Logo needs to change",
        image: fixture_file_upload("moon.jpg", "image/jpeg"),
        description: "Something more in-depth",
        tag_ids: [ tags(:mobile).id ] } }
    assert_response :success

    card = cards(:logo).reload
    assert_equal "Logo needs to change", card.title
    assert_equal "moon.jpg", card.image.filename.to_s
    assert_equal [ tags(:mobile) ], card.tags

    assert_equal "Something more in-depth", card.description.to_plain_text.strip
  end

  test "users can only see cards in collections they have access to" do
    get collection_card_path(collections(:writebook), cards(:logo))
    assert_response :success

    collections(:writebook).update! all_access: false
    collections(:writebook).accesses.revoke_from users(:kevin)
    get collection_card_path(collections(:writebook), cards(:logo))
    assert_response :not_found
  end
end
