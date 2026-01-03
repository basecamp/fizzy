class Account::GithubSetting < ApplicationRecord
  belongs_to :account

  def allows_event?(event_type)
    case event_type
    when "pull_request" then allow_pull_requests
    when "issues" then allow_issues
    when "issue_comment", "pull_request_review_comment" then allow_comments
    when "pull_request_review" then allow_reviews
    else false
    end
  end
end
