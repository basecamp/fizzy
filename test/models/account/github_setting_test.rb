require "test_helper"

class Account::GithubSettingTest < ActiveSupport::TestCase
  test "allows_event? returns true for pull_request when allow_pull_requests is true" do
    setting = account_github_settings(:first_account)
    assert setting.allow_pull_requests
    assert setting.allows_event?("pull_request")
  end

  test "allows_event? returns false for pull_request when allow_pull_requests is false" do
    setting = account_github_settings(:second_account)
    setting.update!(allow_pull_requests: false)
    assert_not setting.allows_event?("pull_request")
  end

  test "allows_event? returns true for issues when allow_issues is true" do
    setting = account_github_settings(:first_account)
    assert setting.allow_issues
    assert setting.allows_event?("issues")
  end

  test "allows_event? returns false for issues when allow_issues is false" do
    setting = account_github_settings(:second_account)
    assert_not setting.allow_issues
    assert_not setting.allows_event?("issues")
  end

  test "allows_event? returns true for issue_comment when allow_comments is true" do
    setting = account_github_settings(:first_account)
    assert setting.allow_comments
    assert setting.allows_event?("issue_comment")
  end

  test "allows_event? returns true for pull_request_review_comment when allow_comments is true" do
    setting = account_github_settings(:first_account)
    assert setting.allow_comments
    assert setting.allows_event?("pull_request_review_comment")
  end

  test "allows_event? returns false for comments when allow_comments is false" do
    setting = account_github_settings(:second_account)
    setting.update!(allow_comments: false)
    assert_not setting.allows_event?("issue_comment")
    assert_not setting.allows_event?("pull_request_review_comment")
  end

  test "allows_event? returns true for pull_request_review when allow_reviews is true" do
    setting = account_github_settings(:first_account)
    assert setting.allow_reviews
    assert setting.allows_event?("pull_request_review")
  end

  test "allows_event? returns false for pull_request_review when allow_reviews is false" do
    setting = account_github_settings(:second_account)
    assert_not setting.allow_reviews
    assert_not setting.allows_event?("pull_request_review")
  end

  test "allows_event? returns false for unknown event type" do
    setting = account_github_settings(:first_account)
    assert_not setting.allows_event?("unknown_event")
  end
end
