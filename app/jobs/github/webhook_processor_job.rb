class Github::WebhookProcessorJob < ApplicationJob
  queue_as :default

  def perform(integration_id, delivery_id, event_type, payload_json)
    integration = GithubIntegration.find(integration_id)
    delivery = GithubIntegration::Delivery.find(delivery_id)
    payload = JSON.parse(payload_json)

    # Set Current.user to system user so event tracking in callbacks works
    Current.user = integration.account.system_user

    unless integration.should_sync_event?(event_type)
      delivery.record_success
      return
    end

    case event_type
    when "pull_request"
      integration.sync_pull_request(payload)
    when "issues"
      integration.sync_issue(payload)
    when "issue_comment"
      sync_issue_comment(integration, payload)
    when "pull_request_review_comment"
      sync_pr_review_comment(integration, payload)
    when "pull_request_review"
      integration.sync_review(payload["pull_request"]["id"], payload["review"], pr_data: payload["pull_request"])
    end

    delivery.record_success
  rescue => error
    delivery.record_error(error.message)
    raise
  end

  private
    def sync_issue_comment(integration, payload)
      item_id = payload["issue"]["id"]
      integration.sync_comment(item_id, payload["comment"], item_data: payload["issue"], item_type: "issue")
    end

    def sync_pr_review_comment(integration, payload)
      item_id = payload["pull_request"]["id"]
      integration.sync_comment(item_id, payload["comment"], item_data: payload["pull_request"], item_type: "pull_request")
    end
end
