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
    assert_redirected_to card_draft_path(card)

    assert card.drafted?
  end

  test "create resumes existing draft if it exists" do
    draft = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    assert_no_difference -> { Card.count } do
      post board_cards_path(boards(:writebook))
      assert_redirected_to card_draft_path(draft)
    end
  end

  test "show redirects to draft when card is drafted" do
    card = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    get card_path(card)
    assert_redirected_to card_draft_path(card)
  end

  test "show" do
    get card_path(cards(:logo))
    assert_response :success
  end

  test "edit" do
    get edit_card_path(cards(:logo))
    assert_response :success
  end

  test "edit card with invalid attachments in description" do
    card = cards(:logo)
    card.update! description: <<~HTML
      <action-text-attachment sgid="gid://fizzy/Card/nonexistent" content-type="application/octet-stream"></action-text-attachment>
    HTML

    get edit_card_path(card)
    assert_response :success
  end

  test "update" do
    patch card_path(cards(:logo)), as: :turbo_stream, params: {
      card: {
        title: "Logo needs to change",
        image: fixture_file_upload("moon.jpg", "image/jpeg"),
        description: "Something more in-depth" } }
    assert_response :success

    card = cards(:logo).reload
    assert_equal "Logo needs to change", card.title
    assert_equal "moon.jpg", card.image.filename.to_s
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
    card.comments.create! \
      creator: users(:kevin),
      body: '<action-text-attachment url="image.png" content-type="image/*" presentation="gallery"></action-text-attachment>'

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
    assert_equal card.closed?, @response.parsed_body["closed"]
    assert_equal 2, @response.parsed_body["steps"].size
    assert_equal card_comments_url(card), @response.parsed_body["comments_url"]
    assert_equal card_reactions_url(card), @response.parsed_body["reactions_url"]
  end

  test "create as JSON" do
    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "My new card", description: "Big if true" } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal card_path(card, format: :json), @response.headers["Location"]

    assert_equal "My new card", card.title
    assert_equal "Big if true", card.description.to_plain_text
  end

  test "create as JSON with custom created_at" do
    custom_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Backdated card", created_at: custom_time } },
        as: :json
      assert_response :created
    end

    assert_equal custom_time, Card.last.created_at
  end

  test "create as JSON with custom last_active_at" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)
    last_active_time = Time.utc(2024, 6, 1, 12, 0, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Card with activity", created_at: created_time, last_active_at: last_active_time } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal created_time, card.created_at
    assert_equal last_active_time, card.last_active_at
  end

  test "create as JSON defaults last_active_at to created_at when not provided" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Backdated card without last_active_at", created_at: created_time } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal created_time, card.created_at
    assert_equal created_time, card.last_active_at
  end

  test "update as JSON with custom last_active_at" do
    card = cards(:logo)
    custom_time = Time.utc(2024, 3, 15, 14, 0, 0)

    put card_path(card, format: :json), params: { card: { last_active_at: custom_time } }

    assert_response :success
    assert_equal custom_time, card.reload.last_active_at
  end

  test "update as JSON can restore last_active_at after comments overwrite it" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)
    last_active_time = Time.utc(2024, 6, 1, 12, 0, 0)

    # Create a card with custom timestamps (simulating import)
    post board_cards_path(boards(:writebook)),
      params: { card: { title: "Imported card", created_at: created_time, last_active_at: last_active_time } },
      as: :json
    assert_response :created

    card = Card.last

    # Adding a comment overwrites last_active_at (this is expected)
    card.comments.create!(creator: users(:kevin), body: "Imported comment")
    assert_not_equal last_active_time, card.reload.last_active_at

    # After import, restore the correct last_active_at
    put card_path(card, format: :json), params: { card: { last_active_at: last_active_time } }
    assert_response :success

    assert_equal last_active_time, card.reload.last_active_at
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
