require "test_helper"

class Webhooks::DeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index as JSON" do
    webhook = webhooks(:active)
    delivery = webhook_deliveries(:successfully_completed)
    webhook_timestamp = delivery.event.created_at.utc.iso8601
    delivery.update!(
      request: {
        headers: {
          "User-Agent" => "fizzy/1.0.0 Webhook",
          "Content-Type" => "application/json",
          "X-Webhook-Signature" => "super-secret-signature",
          "X-Webhook-Timestamp" => webhook_timestamp
        }
      },
      response: { code: 200 }
    )

    get board_webhook_deliveries_path(webhook.board, webhook), as: :json

    assert_response :success
    assert_kind_of Array, @response.parsed_body
    assert_equal webhook.deliveries.count, @response.parsed_body.count
    assert_equal webhook.deliveries.ordered.pluck(:id), @response.parsed_body.pluck("id")

    completed_delivery = @response.parsed_body.find { |record| record["id"] == delivery.id }

    assert_equal "completed", completed_delivery["state"]
    assert_equal delivery.created_at.utc.iso8601(3), completed_delivery["created_at"]
    assert_equal delivery.updated_at.utc.iso8601(3), completed_delivery["updated_at"]
    assert_equal "fizzy/1.0.0 Webhook", completed_delivery.dig("request", "headers", "User-Agent")
    assert_equal "application/json", completed_delivery.dig("request", "headers", "Content-Type")
    assert_equal webhook_timestamp, completed_delivery.dig("request", "headers", "X-Webhook-Timestamp")
    assert_not completed_delivery.dig("request", "headers").key?("X-Webhook-Signature")
    assert_equal 200, completed_delivery.dig("response", "code")
    assert_nil completed_delivery.dig("response", "error")
    assert_equal delivery.event.id, completed_delivery.dig("event", "id")
    assert_equal delivery.event.action, completed_delivery.dig("event", "action")
    assert_equal delivery.event.created_at.utc.iso8601(3), completed_delivery.dig("event", "created_at")
    assert_equal delivery.event.creator_id, completed_delivery.dig("event", "creator", "id")
    assert_equal delivery.event.creator.name, completed_delivery.dig("event", "creator", "name")
    assert_equal delivery.event.eventable_type, completed_delivery.dig("event", "eventable", "type")
    assert_equal delivery.event.eventable_id, completed_delivery.dig("event", "eventable", "id")
    assert_equal polymorphic_url(delivery.event.eventable), completed_delivery.dig("event", "eventable", "url")

    pending_delivery = @response.parsed_body.find { |record| record["id"] == webhook_deliveries(:pending).id }
    assert_nil pending_delivery["request"]
    assert_nil pending_delivery["response"]
  end

  test "index defaults to JSON" do
    webhook = webhooks(:active)

    get board_webhook_deliveries_path(webhook.board, webhook)

    assert_response :success
    assert_equal "application/json; charset=utf-8", @response.headers["Content-Type"]
  end

  test "index rejects HTML" do
    webhook = webhooks(:active)

    get board_webhook_deliveries_path(webhook.board, webhook, format: :html)

    assert_response :not_acceptable
  end

  test "non-admin cannot access deliveries as JSON" do
    logout_and_sign_in_as :jz
    webhook = webhooks(:active)

    get board_webhook_deliveries_path(webhook.board, webhook), as: :json

    assert_response :forbidden
  end

  test "cannot access deliveries on board without access as JSON" do
    logout_and_sign_in_as :jason
    webhook = webhooks(:inactive)

    get board_webhook_deliveries_path(webhook.board, webhook), as: :json

    assert_response :not_found
  end
end
