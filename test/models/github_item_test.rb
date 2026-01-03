require "test_helper"

class GithubItemTest < ActiveSupport::TestCase
  test "validates github_id presence" do
    item = GithubItem.new(
      card: cards(:logo),
      github_integration: github_integrations(:first),
      github_type: "pull_request"
    )
    assert_not item.valid?
    assert item.errors[:github_id].any?
  end

  test "validates github_id uniqueness per integration" do
    existing = github_items(:pull_request_one)
    item = GithubItem.new(
      card: cards(:layout),
      github_integration: existing.github_integration,
      github_id: existing.github_id,
      github_type: "pull_request"
    )
    assert_not item.valid?
    assert item.errors[:github_id].any?
  end

  test "validates github_type inclusion" do
    item = GithubItem.new(
      card: cards(:logo),
      github_integration: github_integrations(:first),
      github_id: 123,
      github_type: "invalid_type"
    )
    assert_not item.valid?
    assert item.errors[:github_type].any?
  end

  test "allows pull_request type" do
    item = GithubItem.new(
      card: cards(:logo),
      github_integration: github_integrations(:first),
      github_id: 999,
      github_type: "pull_request",
      github_url: "https://github.com/test/repo/pull/1",
      github_number: 1
    )
    assert item.valid?
  end

  test "allows issue type" do
    item = GithubItem.new(
      card: cards(:logo),
      github_integration: github_integrations(:first),
      github_id: 888,
      github_type: "issue",
      github_url: "https://github.com/test/repo/issues/1",
      github_number: 1
    )
    assert item.valid?
  end

  test "pull_requests scope returns only pull requests" do
    items = GithubItem.pull_requests
    assert items.all? { |item| item.github_type == "pull_request" }
  end

  test "issues scope returns only issues" do
    items = GithubItem.issues
    assert items.all? { |item| item.github_type == "issue" }
  end

  test "open scope returns only open items" do
    items = GithubItem.open
    assert items.all? { |item| item.state == "open" }
  end

  test "closed scope returns only closed items" do
    items = GithubItem.closed
    assert items.all? { |item| item.state == "closed" }
  end
end
