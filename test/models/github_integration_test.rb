require "test_helper"

class GithubIntegrationTest < ActiveSupport::TestCase
  test "creates with secure webhook secret" do
    integration = github_integrations(:first)
    assert integration.webhook_secret.present?
    assert_equal 20, integration.webhook_secret.length
  end

  test "validates repository full name format" do
    integration = GithubIntegration.new(
      board: boards(:writebook),
      repository_full_name: "invalid"
    )
    assert_not integration.valid?
    assert integration.errors[:repository_full_name].any?
  end

  test "validates repository full name presence" do
    integration = GithubIntegration.new(
      board: boards(:writebook),
      repository_full_name: nil
    )
    assert_not integration.valid?
    assert integration.errors[:repository_full_name].any?
  end

  test "validates uniqueness of repository per board" do
    existing = github_integrations(:first)
    integration = GithubIntegration.new(
      board: existing.board,
      repository_full_name: existing.repository_full_name
    )
    assert_not integration.valid?
    assert integration.errors[:repository_full_name].any?
  end

  test "allows same repository on different boards" do
    integration = GithubIntegration.new(
      board: boards(:private),
      repository_full_name: github_integrations(:first).repository_full_name
    )
    assert integration.valid?
  end

  test "activate sets active to true" do
    integration = github_integrations(:inactive)
    assert_not integration.active?

    integration.activate
    assert integration.active?
  end

  test "deactivate sets active to false" do
    integration = github_integrations(:first)
    assert integration.active?

    integration.deactivate
    assert_not integration.active?
  end

  test "should_sync_event returns false when inactive" do
    integration = github_integrations(:inactive)
    assert_not integration.should_sync_event?("pull_request")
  end

  test "should_sync_event returns false when account disallows event" do
    integration = github_integrations(:second)
    assert integration.active?
    assert integration.sync_issues
    assert_not integration.account.github_setting.allows_event?("issues")

    assert_not integration.should_sync_event?("issues")
  end

  test "should_sync_event returns false when integration disables event" do
    integration = github_integrations(:second)
    assert integration.active?
    assert_not integration.sync_reviews

    assert_not integration.should_sync_event?("pull_request_review")
  end

  test "should_sync_event returns true when both account and integration allow" do
    integration = github_integrations(:first)
    assert integration.active?
    assert integration.sync_pull_requests
    assert integration.account.github_setting.allows_event?("pull_request")

    assert integration.should_sync_event?("pull_request")
  end

  test "webhook_url generates correct URL" do
    integration = github_integrations(:first)
    url = integration.webhook_url

    assert url.include?(integration.id)
    assert url.include?("github/webhooks")
  end

  test "sync_pull_request creates card for opened PR" do
    integration = github_integrations(:first)
    payload = {
      "action" => "opened",
      "pull_request" => {
        "id" => 999888777,
        "number" => 42,
        "state" => "open",
        "title" => "Add new feature",
        "body" => "This PR adds a cool feature",
        "html_url" => "https://github.com/basecamp/fizzy/pull/42",
        "user" => { "login" => "octocat" }
      }
    }

    assert_difference "Card.count", 1 do
      assert_difference "GithubItem.count", 1 do
        integration.sync_pull_request(payload)
      end
    end

    github_item = GithubItem.last
    assert_equal 999888777, github_item.github_id
    assert_equal "pull_request", github_item.github_type
    assert_equal "Add new feature", github_item.card.title
  end

  test "sync_issue creates card for opened issue" do
    integration = github_integrations(:first)
    payload = {
      "action" => "opened",
      "issue" => {
        "id" => 555666777,
        "number" => 100,
        "state" => "open",
        "title" => "Bug report",
        "body" => "Found a bug",
        "html_url" => "https://github.com/basecamp/fizzy/issues/100",
        "user" => { "login" => "bugfinder" }
      }
    }

    assert_difference "Card.count", 1 do
      assert_difference "GithubItem.count", 1 do
        integration.sync_issue(payload)
      end
    end

    github_item = GithubItem.last
    assert_equal 555666777, github_item.github_id
    assert_equal "issue", github_item.github_type
    assert_equal "Bug report", github_item.card.title
  end

  test "sync_pull_request updates existing card for edited PR" do
    github_item = github_items(:pull_request_one)
    integration = github_item.github_integration

    payload = {
      "action" => "edited",
      "pull_request" => {
        "id" => github_item.github_id,
        "number" => github_item.github_number,
        "state" => "open",
        "title" => "Updated PR title",
        "body" => "Updated body",
        "html_url" => github_item.github_url,
        "user" => { "login" => "octocat" }
      }
    }

    assert_no_difference "Card.count" do
      integration.sync_pull_request(payload)
    end

    github_item.card.reload
    assert_equal "Updated PR title", github_item.card.title
  end

  test "sync_pull_request closes card when PR is closed" do
    github_item = github_items(:pull_request_one)
    integration = github_item.github_integration
    card = github_item.card

    payload = {
      "action" => "closed",
      "pull_request" => {
        "id" => github_item.github_id,
        "merged" => false,
        "state" => "closed"
      }
    }

    assert_not card.closed?

    assert_difference "Comment.count", 1 do
      integration.sync_pull_request(payload)
    end

    card.reload
    assert card.closed?
    assert_equal "Closed on GitHub", card.comments.last.body.to_plain_text.strip
  end

  test "sync_comment adds comment to card" do
    github_item = github_items(:pull_request_one)
    integration = github_item.github_integration

    comment_data = {
      "user" => { "login" => "commenter" },
      "body" => "Great work!",
      "html_url" => "https://github.com/basecamp/fizzy/pull/1#comment"
    }

    assert_difference "Comment.count", 1 do
      integration.sync_comment(github_item.github_id, comment_data)
    end

    comment = Comment.last
    assert_includes comment.body.to_s, "commenter"
    assert_includes comment.body.to_s, "Great work!"
  end
end
