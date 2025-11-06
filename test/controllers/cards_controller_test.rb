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

  test "create a new draft" do
    assert_difference -> { Card.count }, 1 do
      post board_cards_path(boards(:writebook))
    end

    assert Card.last.drafted?
    assert_redirected_to Card.last
  end

  test "create resumes existing draft if it exists" do
    draft = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    assert_no_difference -> { Card.count } do
      post board_cards_path(boards(:writebook))
    end

    assert_redirected_to draft
  end

  test "show" do
    get card_path(cards(:logo))
    assert_response :success
  end

  test "edit" do
    get edit_card_path(cards(:logo))
    assert_response :success
  end

  test "update" do
    patch card_path(cards(:logo)), params: {
      card: {
        title: "Logo needs to change",
        image: fixture_file_upload("moon.jpg", "image/jpeg"),
        description: "Something more in-depth",
        tag_ids: [ tags(:mobile).id ] } }
    assert_redirected_to card_path(cards(:logo))

    card = cards(:logo).reload
    assert_equal "Logo needs to change", card.title
    assert_equal "moon.jpg", card.image.filename.to_s
    assert_equal [ tags(:mobile) ], card.tags

    assert_equal "Something more in-depth", card.description.to_plain_text.strip
  end

  test "users can only see cards in boards they have access to" do
    get card_path(cards(:logo))
    assert_response :success

    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from users(:kevin)
    get card_path(cards(:logo))
    assert_response :not_found
  end

  test "admins can see delete button on any card" do
    get card_path(cards(:logo))
    assert_response :success
    assert_match "Delete this card", response.body
  end

  test "card creators can see delete button on their own cards" do
    logout_and_sign_in_as :david

    get card_path(cards(:logo))
    assert_response :success
    assert_match "Delete this card", response.body
  end

  test "non-admins cannot see delete button on cards they did not create" do
    logout_and_sign_in_as :jz

    get card_path(cards(:logo))
    assert_response :success
    assert_no_match "Delete this card", response.body
  end

  test "non-admins cannot delete cards they did not create" do
    logout_and_sign_in_as :jz

    assert_no_difference -> { Card.count } do
      delete card_path(cards(:logo))
    end

    assert_response :forbidden
  end

  test "card creators can delete their own cards" do
    logout_and_sign_in_as :david

    assert_difference -> { Card.count }, -1 do
      delete card_path(cards(:logo))
    end

    assert_redirected_to boards(:writebook)
  end

  test "admins can delete any card" do
    assert_difference -> { Card.count }, -1 do
      delete card_path(cards(:logo))
    end

    assert_redirected_to boards(:writebook)
  end
end
