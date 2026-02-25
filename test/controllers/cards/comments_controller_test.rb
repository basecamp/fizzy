require "test_helper"

class Cards::CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_difference -> { cards(:logo).comments.count }, +1 do
      post card_comments_path(cards(:logo)), params: { comment: { body: "Agreed." } }, as: :turbo_stream
    end

    assert_response :success
  end

  test "create on draft card is forbidden" do
    draft_card = boards(:writebook).cards.create!(status: :drafted, creator: users(:kevin))

    assert_no_difference -> { draft_card.comments.count } do
      post card_comments_path(draft_card), params: { comment: { body: "This should be forbidden" } }, as: :json
    end

    assert_response :forbidden
  end

  test "update" do
    put card_comment_path(cards(:logo), comments(:logo_agreement_kevin)), params: { comment: { body: "I've changed my mind" } }, as: :turbo_stream

    assert_response :success
    assert_action_text "I've changed my mind", comments(:logo_agreement_kevin).reload.body
  end

  test "update another user's comment" do
    assert_no_changes -> { comments(:logo_agreement_jz).reload.body.to_s } do
      put card_comment_path(cards(:logo), comments(:logo_agreement_jz)), params: { comment: { body: "I've changed my mind" } }, as: :turbo_stream
    end

    assert_response :forbidden
  end

  test "index as JSON" do
    card = cards(:logo)

    get card_comments_path(card), as: :json

    assert_response :success
    assert_equal card.comments.count, @response.parsed_body.count
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_difference -> { card.comments.count }, +1 do
      post card_comments_path(card), params: { comment: { body: "New comment" } }, as: :json
    end

    assert_response :created
    assert_equal card_comment_path(card, Comment.last, format: :json), @response.headers["Location"]
  end

  test "create as JSON with custom created_at" do
    card = cards(:logo)
    custom_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { card.comments.count }, +1 do
      post card_comments_path(card), params: { comment: { body: "Backdated comment", created_at: custom_time } }, as: :json
    end

    assert_response :created
    assert_equal custom_time, Comment.last.created_at
  end

  test "show as JSON" do
    comment = comments(:logo_agreement_kevin)

    get card_comment_path(comment.card, comment), as: :json

    assert_response :success
    assert_equal comment.id, @response.parsed_body["id"]
    assert_equal comment.card.id, @response.parsed_body.dig("card", "id")
    assert_equal card_url(comment.card), @response.parsed_body.dig("card", "url")
    assert_equal card_comment_reactions_url(comment.card, comment), @response.parsed_body["reactions_url"]
    assert_equal card_comment_url(comment.card, comment), @response.parsed_body["url"]
  end

  test "update as JSON" do
    comment = comments(:logo_agreement_kevin)

    put card_comment_path(cards(:logo), comment), params: { comment: { body: "Updated comment" } }, as: :json

    assert_response :success
    assert_equal "Updated comment", comment.reload.body.to_plain_text
  end

  test "destroy as JSON" do
    comment = comments(:logo_agreement_kevin)

    delete card_comment_path(cards(:logo), comment), as: :json

    assert_response :no_content
    assert_not Comment.exists?(comment.id)
  end
end
