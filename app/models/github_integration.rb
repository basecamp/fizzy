class GithubIntegration < ApplicationRecord
  include Colored

  has_secure_token :webhook_secret

  belongs_to :account, default: -> { board.account }
  belongs_to :board
  has_many :github_items, dependent: :destroy
  has_many :deliveries, class_name: "GithubIntegration::Delivery", dependent: :destroy

  validates :repository_full_name, presence: true,
    uniqueness: { scope: :board_id },
    format: { with: /\A[\w\-\.]+\/[\w\-\.]+\z/, message: "must be in format: owner/repo" }

  scope :active, -> { where(active: true) }
  scope :for_repository, ->(repo_name) { where(repository_full_name: repo_name) }

  def activate
    update_column(:active, true)
  end

  def deactivate
    update_column(:active, false)
  end

  def webhook_url
    Rails.application.routes.url_helpers.github_webhooks_url(
      id: id,
      script_name: account.slug,
      host: Rails.application.config.action_mailer.default_url_options[:host]
    )
  end

  def should_sync_event?(event_type)
    return false unless active?

    # Check account-level settings (default to true if not configured)
    return false unless account.github_setting&.allows_event?(event_type) != false

    case event_type
    when "pull_request" then sync_pull_requests
    when "issues" then sync_issues
    when "issue_comment", "pull_request_review_comment" then sync_comments
    when "pull_request_review" then sync_reviews
    else false
    end
  end

  def sync_pull_request(payload)
    case payload["action"]
    when "opened"
      create_card_from_pull_request(payload["pull_request"])
    when "edited"
      update_card_from_pull_request(payload["pull_request"])
    when "closed"
      if payload["pull_request"]["merged"]
        close_card_with_comment(payload["pull_request"], "Merged on GitHub")
      else
        close_card_with_comment(payload["pull_request"], "Closed on GitHub")
      end
    when "reopened"
      reopen_card(payload["pull_request"])
    end
  end

  def sync_issue(payload)
    case payload["action"]
    when "opened"
      create_card_from_issue(payload["issue"])
    when "edited"
      update_card_from_issue(payload["issue"])
    when "closed"
      close_card_with_comment(payload["issue"], "Closed on GitHub")
    when "reopened"
      reopen_card(payload["issue"])
    end
  end

  def sync_comment(github_item_id, comment_data, item_data: nil, item_type: nil)
    github_item = github_items.find_by(github_id: github_item_id)

    # If the item doesn't exist yet (created before webhook was set up), create it now
    unless github_item
      if item_data && item_type
        if item_type == "issue"
          card = create_card_from_issue(item_data)
        elsif item_type == "pull_request"
          card = create_card_from_pull_request(item_data)
        else
          return
        end
        github_item = github_items.find_by(card: card)
      else
        return
      end
    end

    github_item.card.add_github_comment(comment_data)
  end

  def sync_review(pull_request_id, review_data, pr_data: nil)
    github_item = github_items.find_by(github_id: pull_request_id, github_type: "pull_request")

    # If the PR doesn't exist yet (created before webhook was set up), create it now
    unless github_item
      if pr_data
        card = create_card_from_pull_request(pr_data)
        github_item = github_items.find_by(card: card)
      else
        return
      end
    end

    github_item.card.add_github_review(review_data)
  end

  private
    def create_card_from_pull_request(pr_data)
      card = board.cards.create!(
        creator: account.system_user,
        status: "published",
        title: pr_data["title"],
        description: build_pr_description(pr_data)
      )

      github_items.create!(
        card: card,
        github_id: pr_data["id"],
        github_type: "pull_request",
        github_url: pr_data["html_url"],
        github_number: pr_data["number"],
        state: pr_data["state"],
        last_synced_at: Time.current
      )

      card
    end

    def create_card_from_issue(issue_data)
      card = board.cards.create!(
        creator: account.system_user,
        status: "published",
        title: issue_data["title"],
        description: build_issue_description(issue_data)
      )

      github_items.create!(
        card: card,
        github_id: issue_data["id"],
        github_type: "issue",
        github_url: issue_data["html_url"],
        github_number: issue_data["number"],
        state: issue_data["state"],
        last_synced_at: Time.current
      )

      card
    end

    def update_card_from_pull_request(pr_data)
      github_item = github_items.find_by(github_id: pr_data["id"])
      return unless github_item

      github_item.card.update!(
        title: pr_data["title"],
        description: build_pr_description(pr_data)
      )
      github_item.update!(state: pr_data["state"], last_synced_at: Time.current)
    end

    def update_card_from_issue(issue_data)
      github_item = github_items.find_by(github_id: issue_data["id"])
      return unless github_item

      github_item.card.update!(
        title: issue_data["title"],
        description: build_issue_description(issue_data)
      )
      github_item.update!(state: issue_data["state"], last_synced_at: Time.current)
    end

    def close_card_with_comment(item_data, reason)
      github_item = github_items.find_by(github_id: item_data["id"])
      return unless github_item

      github_item.card.close unless github_item.card.closed?
      github_item.card.comments.create!(
        creator: account.system_user,
        body: reason
      )
      github_item.update!(state: "closed", last_synced_at: Time.current)
    end

    def reopen_card(item_data)
      github_item = github_items.find_by(github_id: item_data["id"])
      return unless github_item

      github_item.card.reopen if github_item.card.closed?
      github_item.update!(state: "open", last_synced_at: Time.current)
    end

    def build_pr_description(pr_data)
      <<~HTML
        <p><strong>GitHub Pull Request ##{pr_data["number"]}</strong></p>
        <p><a href="#{pr_data["html_url"]}">#{pr_data["html_url"]}</a></p>
        <p>Author: #{pr_data["user"]["login"]}</p>
        #{pr_data["body"] ? "<p>#{pr_data["body"]}</p>" : ""}
      HTML
    end

    def build_issue_description(issue_data)
      <<~HTML
        <p><strong>GitHub Issue ##{issue_data["number"]}</strong></p>
        <p><a href="#{issue_data["html_url"]}">#{issue_data["html_url"]}</a></p>
        <p>Author: #{issue_data["user"]["login"]}</p>
        #{issue_data["body"] ? "<p>#{issue_data["body"]}</p>" : ""}
      HTML
    end
end
