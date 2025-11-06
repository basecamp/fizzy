require "test_helper"

class Webhooks::ActivationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    webhook = webhooks(:inactive)

    assert_not webhook.active?

    assert_changes -> { webhook.reload.active? }, from: false, to: true do
      post board_webhook_activation_path(webhook.board, webhook)
    end

    assert_redirected_to board_webhook_path(webhook.board, webhook)
  end
end
