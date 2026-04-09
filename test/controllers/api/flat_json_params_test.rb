require "test_helper"

class FlatJsonParamsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update user role with flat JSON" do
    put user_role_path(users(:david)), params: { role: "admin" }, as: :json

    assert_response :no_content
    assert users(:david).reload.admin?
  end

  test "update notification settings with flat JSON" do
    logout_and_sign_in_as :david

    assert_changes -> { users(:david).reload.settings.bundle_email_frequency }, from: "never", to: "every_few_hours" do
      put notifications_settings_path, params: { bundle_email_frequency: "every_few_hours" }, as: :json
    end

    assert_response :no_content
  end

  test "update join code with flat JSON" do
    put account_join_code_path, params: { usage_limit: 5 }, as: :json

    assert_response :no_content
    assert_equal 5, Current.account.join_code.reload.usage_limit
  end

  test "update account settings with flat JSON" do
    put account_settings_path, params: { name: "New Name" }, as: :json

    assert_response :no_content
    assert_equal "New Name", Current.account.reload.name
  end

  test "update board entropy with flat JSON" do
    board = boards(:writebook)

    put board_entropy_path(board), params: { auto_postpone_period_in_days: 90 }, as: :json

    assert_response :success
    assert_equal 90.days, board.entropy.reload.auto_postpone_period
  end

  test "update account entropy with flat JSON" do
    put account_entropy_path, params: { auto_postpone_period_in_days: 7 }, as: :json

    assert_response :success
    assert_equal 7.days, Current.account.entropy.reload.auto_postpone_period
  end

  test "create push subscription with flat JSON" do
    stub_dns_resolution("142.250.185.206")

    post user_push_subscriptions_path(users(:kevin)),
      params: { endpoint: "https://fcm.googleapis.com/fcm/send/abc123", p256dh_key: "key1", auth_key: "key2" },
      as: :json

    assert_response :created
  end

  test "create card with flat JSON" do
    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { title: "Flat card", description: "<p>Flat description</p>" },
        as: :json
    end

    assert_response :created
    card = Card.last
    assert_equal "Flat card", card.title
    assert_equal "Flat description", card.description.to_plain_text
  end

  test "update card with flat JSON" do
    card = cards(:logo)

    put card_path(card),
      params: { title: "Flat update", description: "<p>Updated flat</p>" },
      as: :json

    assert_response :success
    card.reload
    assert_equal "Flat update", card.title
    assert_equal "Updated flat", card.description.to_plain_text
  end

  test "create board with flat JSON" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { name: "Flat board" }, as: :json
    end

    assert_response :created
    assert_equal "Flat board", Board.last.name
  end

  test "update board with flat JSON" do
    board = boards(:writebook)

    put board_path(board),
      params: { name: "Flat board", auto_postpone_period_in_days: 7, public_description: "<p>Flat public desc</p>" },
      as: :json

    assert_response :no_content
    board.reload
    assert_equal "Flat board", board.name
    assert_equal 7.days, board.entropy.auto_postpone_period
    assert_equal "Flat public desc", board.public_description.to_plain_text
  end

  test "create column with flat JSON" do
    board = boards(:writebook)

    assert_difference -> { board.columns.count }, +1 do
      post board_columns_path(board), params: { name: "Flat Column" }, as: :json
    end

    assert_response :created
    assert_equal "Flat Column", Column.last.name
  end

  test "update column with flat JSON" do
    column = columns(:writebook_in_progress)

    put board_column_path(column.board, column), params: { name: "Flat Updated" }, as: :json

    assert_response :no_content
    assert_equal "Flat Updated", column.reload.name
  end

  test "create step with flat JSON" do
    card = cards(:logo)

    assert_difference -> { card.steps.count }, +1 do
      post card_steps_path(card), params: { content: "Flat step" }, as: :json
    end

    assert_response :created
    assert_equal "Flat step", Step.last.content
  end

  test "update step with flat JSON" do
    card = cards(:logo)
    step = card.steps.create!(content: "Original")

    put card_step_path(card, step), params: { content: "Flat updated" }, as: :json

    assert_response :success
    assert_equal "Flat updated", step.reload.content
  end

  test "create card reaction with flat JSON" do
    card = cards(:logo)

    assert_difference -> { card.reactions.count }, +1 do
      post card_reactions_path(card), params: { content: "🎉" }, as: :json
    end

    assert_response :created
  end

  test "create comment reaction with flat JSON" do
    comment = comments(:logo_agreement_kevin)

    assert_difference -> { comment.reactions.count }, +1 do
      post card_comment_reactions_path(comment.card, comment), params: { content: "👍" }, as: :json
    end

    assert_response :created
  end

  test "create access token with flat JSON" do
    assert_difference -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { description: "Flat token", permission: "read" }, as: :json
    end

    assert_response :created
    assert_equal "Flat token", @response.parsed_body["description"]
  end

  test "update user with flat JSON" do
    put user_path(users(:david)), params: { name: "Flat Name" }, as: :json

    assert_response :no_content
    assert_equal "Flat Name", users(:david).reload.name
  end

  test "create webhook with flat JSON" do
    board = boards(:writebook)

    assert_difference -> { Webhook.count }, +1 do
      post board_webhooks_path(board),
        params: { name: "Flat Webhook", url: "https://example.com/flat", subscribed_actions: [ "card_published" ] },
        as: :json
    end

    assert_response :created
    assert_equal "Flat Webhook", Webhook.last.name
  end

  test "update webhook with flat JSON" do
    webhook = webhooks(:active)

    patch board_webhook_path(webhook.board, webhook),
      params: { name: "Flat Updated", subscribed_actions: [ "card_published" ] },
      as: :json

    assert_response :success
    assert_equal "Flat Updated", webhook.reload.name
  end

  test "create signup with flat JSON" do
    sign_out
    email = "flatjson-#{SecureRandom.hex(6)}@example.com"

    untenanted do
      assert_difference -> { Identity.count }, +1 do
        post signup_path, params: { email_address: email }, as: :json
      end
    end

    assert_response :created
  end

  test "complete signup with flat JSON" do
    signup = Signup.new(email_address: "flatjson-#{SecureRandom.hex(6)}@example.com", full_name: "Flat User")
    signup.create_identity || raise("Failed to create identity")
    logout_and_sign_in_as signup.identity

    untenanted do
      assert_difference -> { Account.count }, +1 do
        post signup_completion_path, params: { full_name: "Flat JSON User" }, as: :json
      end
    end

    assert_response :created
  end

  test "update user via join with flat JSON" do
    logout_and_sign_in_as :david

    post users_joins_path, params: { name: "Flat Join" }, as: :json

    assert_response :no_content
    assert_equal "Flat Join", users(:david).reload.name
  end
end
