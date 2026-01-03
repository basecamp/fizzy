class Github::WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_account
  skip_before_action :verify_authenticity_token

  def create
    Rails.logger.info "=== GitHub Webhook Received ==="
    Rails.logger.info "Integration ID: #{params[:id]}"
    Rails.logger.info "Event Type: #{event_type}"
    Rails.logger.info "Content-Type: #{request.content_type}"

    if integration = verify_and_find_integration
      # GitHub can send webhooks as application/json or application/x-www-form-urlencoded
      # When form-urlencoded, the JSON payload is in the 'payload' parameter
      payload_json = if request.content_type == "application/x-www-form-urlencoded"
        params[:payload]
      else
        @payload
      end

      delivery = integration.deliveries.create!(
        event_type: event_type,
        request: {
          headers: {
            "X-GitHub-Event" => event_type,
            "X-GitHub-Delivery" => request.headers["X-GitHub-Delivery"],
            "X-Hub-Signature-256" => request.headers["X-Hub-Signature-256"]
          },
          payload: JSON.parse(payload_json)
        }
      )
      Github::WebhookProcessorJob.perform_later(integration.id, delivery.id, event_type, payload_json)
      Rails.logger.info "Webhook processed successfully"
      head :ok
    else
      Rails.logger.error "Webhook verification failed"
      head :unauthorized
    end
  end

  private
    def verify_and_find_integration
      integration = GithubIntegration.find_by(id: params[:id])
      unless integration
        Rails.logger.error "Integration not found: #{params[:id]}"
        return nil
      end

      unless verify_signature(integration.webhook_secret)
        Rails.logger.error "Signature verification failed"
        return nil
      end

      integration
    end

    def verify_signature(secret)
      signature = request.headers["X-Hub-Signature-256"]
      unless signature
        Rails.logger.error "No X-Hub-Signature-256 header present"
        return false
      end

      @payload = request.raw_post
      expected_signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, @payload)

      Rails.logger.info "Received signature: #{signature}"
      Rails.logger.info "Expected signature: #{expected_signature}"
      Rails.logger.info "Payload length: #{@payload.bytesize}"

      ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
    end

    def event_type
      request.headers["X-GitHub-Event"]
    end
end
