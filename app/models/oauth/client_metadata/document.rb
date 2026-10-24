# Validates a fetched client metadata document and maps it to the attributes an
# Oauth::Client row takes. Ported from bc3's Oauth::ClientMetadata::Document,
# narrowed to what Fizzy issues: the authorization code grant, refresh tokens,
# public clients and the read and write scopes.
#
# The draft's MUSTs: a JSON object whose client_id member is exactly the URL it
# was fetched from, and no client_secret members. Then the registration checks
# Fizzy's own dynamic registration makes. Unknown members are ignored (RFC 7591
# §2); the honored ones are client_id, client_name, redirect_uris, grant_types,
# scope, token_endpoint_auth_method and token_endpoint_auth_methods_supported.
class Oauth::ClientMetadata::Document
  NAME_MAX_LENGTH = 255

  # What a document that names no scope is provisioned with: both, so the
  # consent screen offers the choice. The person consenting picks.
  DEFAULT_SCOPES = %w[ read write ]

  attr_reader :client_id, :error_description

  def self.parse(body, client_id:)
    new(body, client_id: client_id)
  end

  def initialize(body, client_id:)
    @client_id = client_id
    @members = parse_json(body)
    validate if @members
  end

  def valid?
    @members.present? && error_description.nil?
  end

  def attributes
    { name: name, redirect_uris: redirect_uris, scopes: scopes }
  end

  private
    def parse_json(body)
      body = body.to_s

      # A response can carry bytes that aren't UTF-8. JSON.parse would accept
      # them into a string tagged UTF-8, which then breaks the consent render or
      # fails at the database as a 500.
      if !body.dup.force_encoding(Encoding::UTF_8).valid_encoding?
        @error_description = "metadata document is not valid UTF-8"
        nil
      elsif (parsed = JSON.parse(body)).is_a?(Hash)
        parsed
      else
        @error_description = "metadata document must be a JSON object"
        nil
      end
    rescue JSON::ParserError
      @error_description = "metadata document is not valid JSON"
      nil
    end

    def validate
      validate_client_id_member
      validate_no_symmetric_secrets
      validate_auth_method
      validate_grant_types
      validate_redirect_uris
      validate_scope
    end

    def invalid(description)
      @error_description ||= description
    end

    # The integrity check the whole profile rests on: the document claims the
    # exact URL it came from, compared as strings. Anything else is someone
    # else's document.
    def validate_client_id_member
      unless @members["client_id"] == client_id
        invalid "client_id in the metadata document must exactly equal the document URL"
      end
    end

    # A public document can't hold a secret, so a client_secret member marks one
    # written for some other protocol: refused, not ignored.
    def validate_no_symmetric_secrets
      if @members.keys.any? { |key| key.start_with?("client_secret") }
        invalid "metadata documents must not contain client_secret fields"
      end
    end

    # A metadata document client is public. token_endpoint_auth_methods_supported
    # lists every method a client can use and leaves the choice to us: a list
    # that includes none is provisioned public whatever it prefers (ChatGPT's
    # prefers private_key_jwt, and offers none).
    def validate_auth_method
      preferred = @members["token_endpoint_auth_method"]
      supported = @members["token_endpoint_auth_methods_supported"]

      if @members.key?("token_endpoint_auth_methods_supported") && \
          (!supported.is_a?(Array) || supported.empty? || !supported.all? { |method| method.is_a?(String) })
        invalid "token_endpoint_auth_methods_supported must be a non-empty array of strings"
      elsif @members.key?("token_endpoint_auth_method") && !preferred.is_a?(String)
        invalid "token_endpoint_auth_method must be a string"
      elsif supported && preferred && !supported.include?(preferred)
        invalid "token_endpoint_auth_method must be one of token_endpoint_auth_methods_supported"
      elsif !offered_auth_methods.include?("none")
        invalid "token_endpoint_auth_method must be none for metadata document clients"
      end
    end

    # The supported list when present, else the preference. Silence on both
    # means none (RFC 7591 §2).
    def offered_auth_methods
      @members.fetch("token_endpoint_auth_methods_supported") { [ @members.fetch("token_endpoint_auth_method", "none") ] }
    end

    # A client may claim grants Fizzy never issues (token exchange, say). They
    # simply aren't granted. The one requirement is a grant that starts a flow
    # here, or the client could never authorize.
    def validate_grant_types
      if @members.key?("grant_types")
        claimed = @members["grant_types"]

        if !claimed.is_a?(Array) || !claimed.all? { |grant_type| grant_type.is_a?(String) }
          invalid "grant_types must be an array of strings"
        elsif !claimed.include?("authorization_code")
          invalid "grant_types must include authorization_code"
        end
      end
    end

    # The same bounds dynamic registration holds a client to. Each URI's shape
    # (https or loopback, no fragment) is Oauth::Client's own validation.
    def validate_redirect_uris
      uris = @members["redirect_uris"]

      if !uris.is_a?(Array) || uris.empty? || !uris.all? { |uri| uri.is_a?(String) }
        invalid "redirect_uris must be a non-empty array of strings"
      elsif uris.size > Oauth::Client::MAXIMUM_REDIRECT_URIS
        invalid "redirect_uris may list at most #{Oauth::Client::MAXIMUM_REDIRECT_URIS} URIs"
      end
    end

    # Unknown scopes are dropped, not fatal, but one of Fizzy's must remain, or
    # the client would be granted nothing.
    def validate_scope
      if @members.key?("scope")
        scope = @members["scope"]

        if !scope.is_a?(String)
          invalid "scope must be a string"
        elsif (scope.split & DEFAULT_SCOPES).empty?
          invalid "scope must include read or write"
        end
      end
    end

    def name
      client_name = @members["client_name"]

      if client_name.is_a?(String) && client_name.strip.present?
        client_name.strip.truncate(NAME_MAX_LENGTH)
      else
        URI.parse(client_id).host.truncate(NAME_MAX_LENGTH)
      end
    end

    def redirect_uris
      Array(@members["redirect_uris"]).grep(String)
    end

    # Write permits reads too, so a document asking for write is provisioned
    # with both, as dynamic registration does.
    def scopes
      if @members["scope"].is_a?(String)
        Oauth.canonical_scope(@members["scope"]).split
      else
        DEFAULT_SCOPES
      end
    end
end
