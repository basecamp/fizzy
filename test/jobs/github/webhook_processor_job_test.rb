require "test_helper"

class Github::WebhookProcessorJobTest < ActiveJob::TestCase
  test "processes pull_request event" do
    integration = github_integrations(:first)
    payload = {
      "action" => "opened",
      "pull_request" => {
        "id" => 777888999,
        "number" => 50,
        "state" => "open",
        "title" => "Test PR",
        "body" => "Test body",
        "html_url" => "https://github.com/test/repo/pull/50",
        "user" => { "login" => "testuser" }
      }
    }.to_json

    delivery = integration.deliveries.create!(event_type: "pull_request", request: {})

    assert_difference "Card.count", 1 do
      Github::WebhookProcessorJob.perform_now(integration.id, delivery.id, "pull_request", payload)
    end

    assert delivery.reload.succeeded?
  end

  test "processes issues event" do
    integration = github_integrations(:first)
    payload = {
      "action" => "opened",
      "issue" => {
        "id" => 444555666,
        "number" => 25,
        "state" => "open",
        "title" => "Test Issue",
        "body" => "Issue body",
        "html_url" => "https://github.com/test/repo/issues/25",
        "user" => { "login" => "issueuser" }
      }
    }.to_json

    delivery = integration.deliveries.create!(event_type: "issues", request: {})

    assert_difference "Card.count", 1 do
      Github::WebhookProcessorJob.perform_now(integration.id, delivery.id, "issues", payload)
    end

    assert delivery.reload.succeeded?
  end

  test "processes issue_comment event" do
    github_item = github_items(:pull_request_one)
    integration = github_item.github_integration

    payload = {
      "action" => "created",
      "issue" => { "id" => github_item.github_id },
      "comment" => {
        "user" => { "login" => "commenter" },
        "body" => "Nice work!",
        "html_url" => "https://github.com/test/repo/pull/1#comment"
      }
    }.to_json

    delivery = integration.deliveries.create!(event_type: "issue_comment", request: {})

    assert_difference "Comment.count", 1 do
      Github::WebhookProcessorJob.perform_now(integration.id, delivery.id, "issue_comment", payload)
    end

    assert delivery.reload.succeeded?
  end

  test "processes pull_request_review event" do
    github_item = github_items(:pull_request_one)
    integration = github_item.github_integration

    payload = {
      "action" => "submitted",
      "pull_request" => { "id" => github_item.github_id },
      "review" => {
        "user" => { "login" => "reviewer" },
        "state" => "approved",
        "body" => "LGTM",
        "html_url" => "https://github.com/test/repo/pull/1#review"
      }
    }.to_json

    delivery = integration.deliveries.create!(event_type: "pull_request_review", request: {})

    assert_difference "Comment.count", 1 do
      Github::WebhookProcessorJob.perform_now(integration.id, delivery.id, "pull_request_review", payload)
    end

    assert delivery.reload.succeeded?
  end

  test "does not process event when should_sync_event returns false" do
    integration = github_integrations(:inactive)
    payload = {
      "action" => "opened",
      "pull_request" => {
        "id" => 111,
        "number" => 1,
        "state" => "open",
        "title" => "Test",
        "html_url" => "https://github.com/test/repo/pull/1",
        "user" => { "login" => "test" }
      }
    }.to_json

    delivery = integration.deliveries.create!(event_type: "pull_request", request: {})

    assert_no_difference "Card.count" do
      Github::WebhookProcessorJob.perform_now(integration.id, delivery.id, "pull_request", payload)
    end

    assert delivery.reload.succeeded?, "Delivery should still succeed even when event is not synced"
  end
end
