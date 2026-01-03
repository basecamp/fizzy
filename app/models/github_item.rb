class GithubItem < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card
  belongs_to :github_integration

  validates :github_id, presence: true, uniqueness: { scope: :github_integration_id }
  validates :github_type, inclusion: { in: %w[pull_request issue] }

  scope :pull_requests, -> { where(github_type: "pull_request") }
  scope :issues, -> { where(github_type: "issue") }
  scope :open, -> { where(state: "open") }
  scope :closed, -> { where(state: "closed") }
end
