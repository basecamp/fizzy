module InternalApi
  extend ActiveSupport::Concern

  included do
    before_action :verify_request
  end

  private
    def verify_request
      verify_request_authentication
      verify_request_signature
    end

    def verify_request_authentication
      token = authenticate_with_http_token do |token, options|
        unless ActiveSupport::SecurityUtils.secure_compare(token, InternalApiClient.token)
          return head :unauthorized
        end
      end

      unless token
        head :unauthorized
      end
    end

    def verify_request_signature
      signature = request.headers[InternalApiClient::SIGNATURE_HEADER].to_s
      computed_signature = InternalApiClient.signature_for(request.raw_post)

      unless ActiveSupport::SecurityUtils.secure_compare(signature, computed_signature)
        head :unauthorized
      end
    end
end
