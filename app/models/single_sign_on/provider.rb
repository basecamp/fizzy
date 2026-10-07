class SingleSignOn::Provider
  SIGNING_ALGORITHMS = %w[ RS256 RS384 RS512 PS256 PS384 PS512 ES256 ES384 ES512 ]
  SIGNING_KEY_TYPES = %w[ RSA EC ]
  SCOPES = %w[ openid email profile ]
  CACHE_DURATION = 1.hour
  TIMEOUT = 5.seconds

  attr_reader :issuer, :client_id

  def initialize(issuer:, client_id:, client_secret:)
    @issuer = issuer
    @client_id = client_id
    @client_secret = client_secret
  end

  def authorization_url(redirect_uri:, state:, nonce:, code_challenge:)
    parameters = authorization_parameters(redirect_uri:, state:, nonce:, code_challenge:)

    URI(discovery.fetch("authorization_endpoint")).tap do |uri|
      uri.query = [ uri.query, parameters.to_query ].compact_blank.join("&")
    end.to_s
  end

  def claims_for(code:, redirect_uri:, code_verifier:, nonce:)
    id_token = exchange_code(code:, redirect_uri:, code_verifier:)
    SingleSignOn::IdToken.new(id_token, provider: self).verify(nonce: nonce)
  end

  def signing_keys(refresh: false)
    @signing_keys = nil if refresh
    @signing_keys ||= fetch_keys(refresh: refresh).select { |key| signing_key?(key) }
  end

  # Keys can leave out `alg`, and the jwt gem checks the algorithm before it fetches new keys.
  def signing_algorithms
    algorithms = signing_keys.filter_map { |key| key["alg"] } | Array(discovery["id_token_signing_alg_values_supported"])

    if (supported_algorithms = algorithms & SIGNING_ALGORITHMS).any?
      supported_algorithms
    else
      raise SingleSignOn::ProviderError, "#{issuer} has no supported signing algorithm"
    end
  end

  private
    attr_reader :client_secret

    def authorization_parameters(redirect_uri:, state:, nonce:, code_challenge:)
      {
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: scopes.join(" "),
        state: state,
        nonce: nonce,
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      }
    end

    # Some providers send groups only when the client asks for this scope.
    def scopes
      if Array(discovery["scopes_supported"]).include?("groups")
        SCOPES + %w[ groups ]
      else
        SCOPES
      end
    end

    def discovery
      @discovery ||= Rails.cache.fetch(cache_key(:discovery), expires_in: CACHE_DURATION) do
        get_json(discovery_url).tap { |document| ensure_valid_discovery(document) }
      end
    end

    def discovery_url
      "#{issuer.chomp("/")}/.well-known/openid-configuration"
    end

    def ensure_valid_discovery(document)
      endpoints = document.values_at("authorization_endpoint", "token_endpoint", "jwks_uri")

      if document["issuer"] != issuer
        raise SingleSignOn::ProviderError,
          "Discovery issuer #{document["issuer"].inspect} does not match #{issuer}"
      elsif endpoints.any?(&:blank?)
        raise SingleSignOn::ProviderError, "Discovery document for #{issuer} is missing an endpoint"
      elsif endpoints.any? { |endpoint| !secure_url?(endpoint) }
        raise SingleSignOn::ProviderError, "Discovery document for #{issuer} lists an endpoint without https"
      end
    end

    def secure_url?(url)
      URI(url).scheme == "https" || Rails.env.local?
    end

    def exchange_code(code:, redirect_uri:, code_verifier:)
      parameters = { grant_type: "authorization_code", code: code, redirect_uri: redirect_uri, code_verifier: code_verifier }

      response = case token_endpoint_authentication_method
      when "client_secret_post"
        post_form discovery.fetch("token_endpoint"), parameters.merge(client_id: client_id, client_secret: client_secret)
      when "client_secret_basic"
        post_form discovery.fetch("token_endpoint"), parameters, authorization: basic_authorization
      end

      if id_token = response["id_token"].presence
        id_token
      else
        raise SingleSignOn::ProviderError, "Token response from #{issuer} has no ID token"
      end
    end

    # A discovery document without the list means client_secret_basic, as OpenID Connect Discovery defines.
    def token_endpoint_authentication_method
      methods = Array(discovery["token_endpoint_auth_methods_supported"]).presence || %w[ client_secret_basic ]

      if methods.include?("client_secret_post")
        "client_secret_post"
      elsif methods.include?("client_secret_basic")
        "client_secret_basic"
      else
        raise SingleSignOn::ProviderError,
          "#{issuer} lists neither client_secret_post nor client_secret_basic for its token endpoint"
      end
    end

    # RFC 6749 form-encodes the client ID and the secret before Base64.
    def basic_authorization
      credentials = [ client_id, client_secret ].map { |value| URI.encode_www_form_component(value) }.join(":")
      "Basic #{Base64.strict_encode64(credentials)}"
    end

    def fetch_keys(refresh:)
      Rails.cache.fetch(cache_key(:keys), expires_in: CACHE_DURATION, force: refresh) do
        if (keys = get_json(discovery.fetch("jwks_uri"))["keys"]).is_a?(Array)
          keys
        else
          raise SingleSignOn::ProviderError, "Key set from #{issuer} has no keys"
        end
      end
    end

    def signing_key?(key)
      key.is_a?(Hash) && key["kty"].in?(SIGNING_KEY_TYPES) && key["use"].in?([ nil, "sig" ])
    end

    def cache_key(name)
      [ "single_sign_on", issuer, name ]
    end

    def get_json(url)
      uri = URI(url)
      perform uri, Net::HTTP::Get.new(uri)
    end

    def post_form(url, parameters, authorization: nil)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(parameters)
      request["Authorization"] = authorization if authorization

      perform uri, request
    end

    def perform(uri, request)
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: TIMEOUT, read_timeout: TIMEOUT, write_timeout: TIMEOUT) do |http|
        http.request(request)
      end

      parse_json(response, uri)
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => error
      raise SingleSignOn::ProviderError, "Cannot connect to #{uri.host}: #{error.message}"
    end

    def parse_json(response, uri)
      if response.is_a?(Net::HTTPSuccess) && (document = JSON.parse(response.body)).is_a?(Hash)
        document
      else
        raise SingleSignOn::ProviderError, "#{uri.host} returned HTTP #{response.code} for #{uri.path}"
      end
    rescue JSON::ParserError
      raise SingleSignOn::ProviderError, "#{uri.host} returned a response that is not JSON for #{uri.path}"
    end
end
