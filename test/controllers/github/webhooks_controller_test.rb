require "test_helper"

class Github::WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "accepts valid webhook with correct signature" do
    integration = github_integrations(:first)
    payload = { action: "opened", pull_request: { id: 123 } }.to_json

    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", integration.webhook_secret, payload)

    assert_difference "GithubIntegration::Delivery.count", 1 do
      assert_enqueued_with(job: Github::WebhookProcessorJob) do
        post github_webhooks_path(id: integration.id),
          params: payload,
          headers: {
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Event" => "pull_request",
            "X-GitHub-Delivery" => "12345-67890-abcdef",
            "Content-Type" => "application/json"
          },
          as: :json
      end
    end

    assert_response :ok

    delivery = integration.deliveries.last
    assert_equal "pull_request", delivery.event_type
    assert_equal "pending", delivery.state
  end

  test "rejects webhook with invalid signature" do
    integration = github_integrations(:first)
    payload = { action: "opened" }.to_json

    post github_webhooks_path(id: integration.id),
      params: payload,
      headers: {
        "X-Hub-Signature-256" => "sha256=invalid_signature",
        "X-GitHub-Event" => "pull_request",
        "Content-Type" => "application/json"
      },
      as: :json

    assert_response :unauthorized
  end

  test "rejects webhook with missing signature" do
    integration = github_integrations(:first)
    payload = { action: "opened" }.to_json

    post github_webhooks_path(id: integration.id),
      params: payload,
      headers: {
        "X-GitHub-Event" => "pull_request",
        "Content-Type" => "application/json"
      },
      as: :json

    assert_response :unauthorized
  end

  test "rejects webhook for non-existent integration" do
    payload = { action: "opened" }.to_json
    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "secret", payload)

    post github_webhooks_path(id: "non-existent-id"),
      params: payload,
      headers: {
        "X-Hub-Signature-256" => signature,
        "X-GitHub-Event" => "pull_request",
        "Content-Type" => "application/json"
      },
      as: :json

    assert_response :unauthorized
  end

  test "webhook does not require authentication" do
    # This test verifies that the controller allows unauthenticated access
    integration = github_integrations(:first)
    payload = { action: "opened", pull_request: { id: 456 } }.to_json
    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", integration.webhook_secret, payload)

    # Don't sign in, verify webhook still works
    post github_webhooks_path(id: integration.id),
      params: payload,
      headers: {
        "X-Hub-Signature-256" => signature,
        "X-GitHub-Event" => "pull_request",
        "Content-Type" => "application/json"
      },
      as: :json

    assert_response :ok
  end
end
