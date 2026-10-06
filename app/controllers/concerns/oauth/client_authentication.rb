# Client credentials arrive one of two ways (RFC 6749 §2.3.1):
#
# - client_secret_basic: an Authorization: Basic header carrying the
#   form-urlencoded client_id and client_secret.
# - client_secret_post: client_id and client_secret in the request body. A
#   secret in the query string never authenticates, since secrets there leak
#   into proxy and access logs.
#
# A confidential client may use either, whichever it registered: the
# registered token_endpoint_auth_method is advisory. Using both at once is
# refused, since a client MUST NOT use more than one method per request (§2.3).
module Oauth::ClientAuthentication
  BASIC_SCHEME = /\ABasic /i

  private
    # RFC 6749 §5.2 names more than one authentication method invalid_request.
    # That answer turns on the request's shape alone, so it says nothing about
    # which clients exist. A malformed Basic header, or one naming a different
    # client than the body, fails like any other bad credential.
    def reject_ambiguous_client_credentials
      if client_secret_basic?
        if request.request_parameters["client_secret"].present?
          oauth_error "invalid_request", "Client credentials must use only one authentication method"
        elsif basic_client_credentials.nil? || conflicting_client_id?
          client_authentication_failed
        end
      end
    end

    # The client the request authenticates as, or nil. A confidential client
    # authenticates with its secret. A public client identifies by client_id
    # alone, but never through Basic: it holds no password, so a Basic header
    # naming one is refused rather than downgraded to identification.
    def authenticated_client
      if client = requesting_client
        client if client.confidential? ? client_secret_authenticates?(client) : !client_secret_basic?
      end
    end

    # A request attempts client authentication when it uses Basic, names a
    # confidential client, or carries a client secret. This turns on what the
    # request presents, so refusing a failed attempt reveals nothing about
    # which clients exist.
    def attempts_client_authentication?
      client_secret_basic? || requesting_client&.confidential? || oauth_client_secret.present?
    end

    def requesting_client
      if oauth_client_id
        @requesting_client ||= Oauth::Client.find_by(client_id: oauth_client_id)
      end
    end

    def client_secret_authenticates?(client)
      (client_secret_basic? || request.request_parameters["client_id"] == client.client_id) &&
        client.authenticate_secret(oauth_client_secret)
    end

    # RFC 6749 §5.2: invalid_client may answer 401 to name the schemes the
    # server supports, and must when the client tried the Authorization
    # header. Basic is the one we support, so every failure names it, and
    # the answer is the same for an unknown client and a wrong secret.
    # RFC 7617 defines no error parameter for Basic, only realm.
    def client_authentication_failed
      response.headers["WWW-Authenticate"] = %(Basic realm="#{oauth_issuer}")
      oauth_error "invalid_client", "Client authentication failed", status: :unauthorized
    end

    # Whether the request used the Basic scheme, well-formed or not.
    def client_secret_basic?
      request.authorization.to_s.match?(BASIC_SCHEME)
    end

    def conflicting_client_id?
      params[:client_id].present? && params[:client_id] != basic_client_credentials.first
    end

    # A Basic header wins over the body. Only a scalar String names a client.
    def oauth_client_id
      if client_secret_basic?
        basic_client_credentials&.first
      elsif params[:client_id].is_a?(String)
        params[:client_id]
      end
    end

    def oauth_client_secret
      if client_secret_basic?
        basic_client_credentials&.last
      else
        request.request_parameters["client_secret"]
      end
    end

    # [client_id, client_secret] from Authorization: Basic, or nil when it's
    # malformed. Each half is form-urlencoded before the pair is Basic-encoded
    # (RFC 6749 Appendix B), so the split happens on the first raw colon and
    # each half decodes after it: %3A is a literal colon and + a space.
    def basic_client_credentials
      if defined?(@basic_client_credentials)
        @basic_client_credentials
      else
        @basic_client_credentials = decode_basic_client_credentials
      end
    end

    def decode_basic_client_credentials
      decoded = Base64.strict_decode64(request.authorization.to_s.sub(BASIC_SCHEME, "").strip)
      client_id, client_secret = decoded.split(":", 2).map { |part| URI.decode_www_form_component(part) }

      if client_id.present? && client_secret.is_a?(String) && client_id.valid_encoding? && client_secret.valid_encoding?
        [ client_id, client_secret ]
      end
    rescue ArgumentError
      nil
    end

    # The pilot exemption keys on the client that authenticates, header or body.
    def piloting_client_id
      oauth_client_id
    end
end
