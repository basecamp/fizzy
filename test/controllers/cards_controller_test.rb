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

    card = Card.last
    assert card.drafted?
    assert_redirected_to card
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
    patch card_path(cards(:logo)), as: :turbo_stream, params: {
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

  test "show card with comment containing malformed remote image attachment" do
    card = cards(:logo)
    card.comments.create!(
      creator: users(:kevin),
      body: '<action-text-attachment url="image.png" content-type="image/*" presentation="gallery"></action-text-attachment>'
    )

    get card_path(card)
    assert_response :success
  end

  test "show as JSON" do
    card = cards(:logo)
    card.steps.create!(content: "First step")
    card.steps.create!(content: "Second step", completed: true)

    get card_path(card), as: :json
    assert_response :success
    assert_equal card.title, @response.parsed_body["title"]
    assert_equal 2, @response.parsed_body["steps"].size
  end

  test "create as JSON" do
    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "My new card", description: "Big if true", tag_ids: [ tags(:web).id, tags(:mobile).id ] } },
        as: :json
    end

    assert_response :created
    assert_equal card_path(Card.last, format: :json), @response.headers["Location"]

    card = Card.last
    assert_equal "My new card", card.title
    assert_equal "Big if true", card.description.to_plain_text
    assert_equal [ tags(:mobile), tags(:web) ].sort, card.tags.sort
  end

  test "create as JSON with custom created_at" do
    custom_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Backdated card", created_at: custom_time } },
        as: :json
    end

    assert_response :created
    assert_equal custom_time, Card.last.created_at
  end

  test "update as JSON" do
    card = cards(:logo)
    put card_path(card, format: :json), params: { card: { title: "Update test" } }

    assert_response :success
    assert_equal "Update test", card.reload.title
  end

  test "delete as JSON" do
    card = cards(:logo)
    delete card_path(card, format: :json)

    assert_response :no_content
    assert_not Card.exists?(card.id)
  end
end
