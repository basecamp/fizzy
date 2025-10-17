module InternalApi
  extend ActiveSupport::Concern

  included do
    require_untenanted_access
    skip_before_action :verify_authenticity_token
    before_action :verify_request_authentication
    before_action :verify_request_signature
  end

  private
    def verify_request_authentication
      authenticated = authenticate_with_http_token do |token, options|
        ActiveSupport::SecurityUtils.secure_compare(token, InternalApiClient.token)
      end

      head :unauthorized unless authenticated
    end

    def verify_request_signature
      signature = request.headers[InternalApiClient::SIGNATURE_HEADER].to_s
      computed_signature = InternalApiClient.signature_for(request.raw_post)

      unless ActiveSupport::SecurityUtils.secure_compare(signature, computed_signature)
        head :unauthorized
      end
    end
end
