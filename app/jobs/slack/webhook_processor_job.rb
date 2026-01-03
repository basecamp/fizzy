class Slack::WebhookProcessorJob < ApplicationJob
  queue_as :default

  def perform(integration_id, delivery_id, event_type, payload_json)
    Rails.logger.info "🔄 Processing Slack webhook (Job ID: #{job_id})"
    Rails.logger.info "Integration ID: #{integration_id}"
    Rails.logger.info "Delivery ID: #{delivery_id}"
    Rails.logger.info "Event type: #{event_type}"

    integration = SlackIntegration.find(integration_id)
    delivery = SlackIntegration::Delivery.find(delivery_id)
    payload = JSON.parse(payload_json)

    Rails.logger.info "Integration: #{integration.channel_name} (Board: #{integration.board.name})"

    # Set account context and user so event tracking in callbacks works
    Current.with_account(integration.account) do
      # Use account owner instead of system user
      Current.user = integration.account.users.owner.first || integration.account.system_user

      unless integration.should_sync_event?(event_type)
        Rails.logger.info "⏭️  Event type '#{event_type}' is disabled for this integration, skipping"
        delivery.record_success
        return
      end

      Rails.logger.info "✅ Event type '#{event_type}' is enabled, processing..."

      case event_type
      when "message"
        Rails.logger.info "📝 Syncing message"
        message_data = payload["event"]
        Rails.logger.info "Message text preview: #{message_data['text']&.truncate(100)}"
        Rails.logger.info "Message timestamp: #{message_data['ts']}"

        integration.sync_message(payload)
        Rails.logger.info "✅ Message synced successfully"

      when "reaction_added"
        Rails.logger.info "😀 Processing reaction"
        event_data = payload["event"]
        Rails.logger.info "Emoji: #{event_data['reaction']}"
        Rails.logger.info "Message timestamp: #{event_data.dig('item', 'ts')}"
        Rails.logger.info "User: #{event_data['user']}"

        integration.sync_reaction(payload)
        Rails.logger.info "✅ Reaction processed successfully"
      end

      delivery.record_success
      Rails.logger.info "✅ Webhook processing completed successfully"
    end

  rescue => error
    Rails.logger.error "❌ Error processing webhook: #{error.message}"
    Rails.logger.error "Error class: #{error.class.name}"
    Rails.logger.error "Backtrace:\n#{error.backtrace.first(10).join("\n")}"
    Rails.logger.error "Event type: #{event_type}"
    Rails.logger.error "Integration: #{integration_id}"
    Rails.logger.error "Delivery: #{delivery_id}"

    delivery.record_error(error.message)
    raise
  end
end
