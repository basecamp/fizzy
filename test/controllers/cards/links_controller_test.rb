require "test_helper"

class Cards::LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
    @target = cards(:layout)
  end

  # GET new

  test "GET new renders link picker modal" do
    get new_card_link_path(@card)
    assert_response :success
  end

  test "GET new excludes self from available cards" do
    get new_card_link_path(@card)
    assert_response :success
    assert_no_match /##{@card.number}/, response.body
  end

  test "GET new excludes already linked cards" do
    CardLink.create!(source_card: @card, target_card: @target, link_type: :related)
    get new_card_link_path(@card)
    assert_response :success
  end

  test "GET new respects link_type param" do
    get new_card_link_path(@card, link_type: "parent")
    assert_response :success
    assert_match /btn--active.*Parent/m, response.body
  end

  # POST create

  test "POST create adds link via turbo stream" do
    assert_difference -> { CardLink.count } do
      post card_links_path(@card),
           params: { target_card_id: @target.id, link_type: "related" },
           as: :turbo_stream
    end
    assert_response :success
    assert_turbo_stream action: :replace, target: dom_id(@card, :links)
  end

  test "POST create updates both cards' link sections" do
    post card_links_path(@card),
         params: { target_card_id: @target.id, link_type: "related" },
         as: :turbo_stream

    # Should have two turbo_stream.replace calls
    assert_turbo_stream action: :replace, target: dom_id(@card, :links)
    assert_turbo_stream action: :replace, target: dom_id(@target, :links)
  end

  test "POST create with parent link type" do
    post card_links_path(@card),
         params: { target_card_id: @target.id, link_type: "parent" },
         as: :turbo_stream

    assert_response :success
    link = CardLink.last
    assert_equal "parent", link.link_type
  end

  test "POST create with child link type" do
    post card_links_path(@card),
         params: { target_card_id: @target.id, link_type: "child" },
         as: :turbo_stream

    assert_response :success
    link = CardLink.last
    assert_equal "child", link.link_type
  end

  test "POST create toggles existing link off" do
    CardLink.create!(source_card: @card, target_card: @target, link_type: :related)

    assert_difference -> { CardLink.count }, -1 do
      post card_links_path(@card),
           params: { target_card_id: @target.id, link_type: "related" },
           as: :turbo_stream
    end
    assert_response :success
  end

  test "POST create responds to json" do
    post card_links_path(@card),
         params: { target_card_id: @target.id, link_type: "related" },
         as: :json

    assert_response :no_content
  end

  test "POST create rejects cross-account target" do
    other_card = cards(:radio)

    post card_links_path(@card),
         params: { target_card_id: other_card.id, link_type: "related" },
         as: :turbo_stream

    assert_response :not_found
  end

  # DELETE destroy

  test "DELETE destroy removes link via turbo stream" do
    link = CardLink.create!(source_card: @card, target_card: @target, link_type: :related)

    assert_difference -> { CardLink.count }, -1 do
      delete card_link_path(@card, link), as: :turbo_stream
    end
    assert_response :success
  end

  test "DELETE destroy updates both cards' link sections" do
    link = CardLink.create!(source_card: @card, target_card: @target, link_type: :related)

    delete card_link_path(@card, link), as: :turbo_stream

    assert_turbo_stream action: :replace, target: dom_id(@card, :links)
    assert_turbo_stream action: :replace, target: dom_id(@target, :links)
  end

  test "DELETE destroy responds to json" do
    link = CardLink.create!(source_card: @card, target_card: @target, link_type: :related)

    delete card_link_path(@card, link), as: :json

    assert_response :no_content
  end

  # GET search

  test "GET search finds cards by title" do
    get search_card_links_path(@card), params: { q: @target.title[0..5], link_type: "related" }
    assert_response :success
    assert_match @target.title, response.body
  end

  test "GET search finds cards by number" do
    get search_card_links_path(@card), params: { q: @target.number.to_s, link_type: "related" }
    assert_response :success
    assert_match "##{@target.number}", response.body
  end

  test "GET search excludes self" do
    get search_card_links_path(@card), params: { q: @card.title[0..5], link_type: "related" }
    assert_response :success
    assert_no_match /##{@card.number}/, response.body
  end

  test "GET search only returns cards from same account" do
    other_card = cards(:radio)

    get search_card_links_path(@card), params: { q: other_card.title, link_type: "related" }
    assert_response :success
    assert_no_match other_card.title, response.body
  end
end
