require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get board_webhooks_path(boards(:writebook))
    assert_response :success
  end

  test "show" do
    webhook = webhooks(:active)
    get board_webhook_path(webhook.board, webhook)
    assert_response :success

    webhook = webhooks(:inactive)
    get board_webhook_path(webhook.board, webhook)
    assert_response :success
  end

  test "new" do
    get new_board_webhook_path(boards(:writebook))
    assert_response :success
    assert_select "form"
  end

  test "create with valid params" do
    board = boards(:writebook)

    assert_difference "Webhook.count", 1 do
      post board_webhooks_path(board), params: {
        webhook: {
          name: "Test Webhook",
          url: "https://example.com/webhook",
          subscribed_actions: [ "", "card_published", "card_closed" ]
        }
      }
    end

    webhook = Webhook.last

    assert_redirected_to board_webhook_path(webhook.board, webhook)
    assert_equal board, webhook.board
    assert_equal "Test Webhook", webhook.name
    assert_equal "https://example.com/webhook", webhook.url
    assert_equal [ "card_published", "card_closed" ], webhook.subscribed_actions
  end

  test "create with invalid params" do
    board = boards(:writebook)
    assert_no_difference "Webhook.count" do
      post board_webhooks_path(board), params: {
        webhook: {
          name: "",
          url: "invalid-url"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "edit" do
    webhook = webhooks(:active)
    get edit_board_webhook_path(webhook.board, webhook)
    assert_response :success
    assert_select "form"

    webhook = webhooks(:inactive)
    get edit_board_webhook_path(webhook.board, webhook)
    assert_response :success
    assert_select "form"
  end

  test "update with valid params" do
    webhook = webhooks(:active)
    patch board_webhook_path(webhook.board, webhook), params: {
      webhook: {
        name: "Updated Webhook",
        subscribed_actions: [ "card_published" ]
      }
    }

    webhook.reload

    assert_redirected_to board_webhook_path(webhook.board, webhook)
    assert_equal "Updated Webhook", webhook.name
    assert_equal [ "card_published" ], webhook.subscribed_actions
  end

  test "update with invalid params" do
    webhook = webhooks(:active)
    patch board_webhook_path(webhook.board, webhook), params: {
      webhook: {
        name: ""
      }
    }

    assert_response :unprocessable_entity

    assert_no_changes -> { webhook.reload.url } do
      patch board_webhook_path(webhook.board, webhook), params: {
        webhook: {
          name: "Updated Webhook",
          url: "https://different.com/webhook"
        }
      }
    end

    assert_redirected_to board_webhook_path(webhook.board, webhook)
  end

  test "destroy" do
    webhook = webhooks(:active)

    assert_difference "Webhook.count", -1 do
      delete board_webhook_path(webhook.board, webhook)
    end

    assert_redirected_to board_webhooks_path(webhook.board)
  end

  test "cannot access webhooks on board without access" do
    logout_and_sign_in_as :jason

    webhook = webhooks(:inactive)  # on private board, jason has no access

    get board_webhooks_path(webhook.board)
    assert_response :not_found
  end
end
