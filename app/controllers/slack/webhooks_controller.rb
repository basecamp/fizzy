class Slack::WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_account
  skip_before_action :verify_authenticity_token

  def create
    Rails.logger.info "=" * 80
    Rails.logger.info "=== Slack Webhook Received ==="
    Rails.logger.info "Integration ID: #{params[:id]}"
    Rails.logger.info "Content-Type: #{request.content_type}"
    Rails.logger.info "Timestamp: #{Time.current.iso8601}"
    Rails.logger.info "Request IP: #{request.remote_ip}"

    # Parse JSON body
    begin
      payload = JSON.parse(request.raw_post)
      Rails.logger.info "Payload type: #{payload['type']}"
      Rails.logger.info "Event type: #{payload.dig('event', 'type')}" if payload['event']
    rescue JSON::ParserError => e
      Rails.logger.error "❌ JSON parse error: #{e.message}"
      Rails.logger.error "Raw body preview: #{request.raw_post[0..200]}"
      head :bad_request
      return
    end

    # Slack sends URL verification challenge when setting up webhooks
    # This happens BEFORE signature verification
    if payload["type"] == "url_verification"
      Rails.logger.info "✅ Responding to URL verification challenge: #{payload['challenge']}"
      render json: { challenge: payload["challenge"] }, status: :ok
      return
    end

    # For actual events, verify signature and process
    integration = SlackIntegration.find_by(id: params[:id])
    unless integration
      Rails.logger.error "❌ Integration not found: #{params[:id]}"
      Rails.logger.error "Available integration IDs: #{SlackIntegration.pluck(:id).join(', ')}"
      head :not_found
      return
    end

    Rails.logger.info "Found integration: #{integration.channel_name} (Board: #{integration.board.name})"

    unless verify_signature(integration.webhook_secret)
      Rails.logger.error "❌ Signature verification failed for integration #{integration.id}"
      Rails.logger.error "Check that the signing secret in Fizzy matches your Slack app's signing secret"
      head :unauthorized
      return
    end

    Rails.logger.info "✅ Signature verified successfully"

    # Auto-detect and save bot_user_id from webhook payload
    auto_detect_bot_user_id(integration, payload)

    # Create delivery record and process webhook
    begin
      delivery = integration.deliveries.create!(
        event_type: event_type(payload),
        request: {
          headers: {
            "X-Slack-Request-Timestamp" => request.headers["X-Slack-Request-Timestamp"],
            "X-Slack-Signature" => request.headers["X-Slack-Signature"]
          },
          payload: payload
        }
      )

      Rails.logger.info "Created delivery record: #{delivery.id}"
      Rails.logger.info "Event type: #{event_type(payload)}"

      # Set account context so FizzyActiveJobExtensions can capture it
      Current.with_account(integration.account) do
        Slack::WebhookProcessorJob.perform_later(integration.id, delivery.id, event_type(payload), request.raw_post)
      end
      Rails.logger.info "✅ Webhook queued for processing"
      Rails.logger.info "=" * 80
    rescue => e
      Rails.logger.error "❌ Error creating delivery record: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      head :internal_server_error
      return
    end

    head :ok
  end

  private
    def auto_detect_bot_user_id(integration, payload)
      # Extract bot_user_id from webhook payload authorizations
      bot_user_id = payload.dig("authorizations", 0, "user_id")

      if bot_user_id.present? && bot_user_id != integration.bot_user_id
        Rails.logger.info "🔍 Auto-detected bot_user_id from webhook: #{bot_user_id}"
        integration.update_column(:bot_user_id, bot_user_id)
        Rails.logger.info "✅ Updated integration bot_user_id to: #{bot_user_id}"
      end
    rescue => error
      Rails.logger.warn "⚠️  Failed to auto-detect bot_user_id: #{error.message}"
      # Don't block webhook processing if auto-detection fails
    end

    def verify_signature(secret)
      signature = request.headers["X-Slack-Signature"]
      timestamp = request.headers["X-Slack-Request-Timestamp"]

      unless signature && timestamp
        Rails.logger.error "Missing Slack signature headers"
        return false
      end

      # Prevent replay attacks (request older than 5 minutes)
      if (Time.current.to_i - timestamp.to_i).abs > 60 * 5
        Rails.logger.error "Request timestamp too old"
        return false
      end

      @payload = request.raw_post
      base_string = "v0:#{timestamp}:#{@payload}"
      expected_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", secret, base_string)

      Rails.logger.info "Received signature: #{signature}"
      Rails.logger.info "Expected signature: #{expected_signature}"

      ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
    end

    def event_type(payload)
      payload.dig("event", "type") || payload["type"] || "unknown"
    end
end
