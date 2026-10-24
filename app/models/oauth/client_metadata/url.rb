# The identifier layer of CIMD: the client_id IS the https URL of the client's
# metadata document. Validation is strict shape checking with no normalization:
# client ids compare as exact strings, so nothing here downcases, strips a
# default port or resolves dot-segments. A URL that would need normalizing
# isn't a valid client_id.
module Oauth::ClientMetadata::Url
  extend self

  # oauth_clients.client_id is a 255-character string. Widening it would change
  # an existing column's type, so the identifier is held to what fits.
  MAX_LENGTH = 255

  # Whether a client_id claims to be a URL. Deliberately looser than valid?: a
  # URL-shaped id always takes the metadata document path, where a malformed one
  # is refused, and is never looked up among registered clients.
  def url_shaped?(client_id)
    client_id.is_a?(String) && client_id.match?(%r{\Ahttps?://}i)
  end

  def valid?(client_id)
    parse(client_id).present?
  end

  # The parsed URI when the client_id meets every identifier rule, nil
  # otherwise: https exactly (a case variant is a different string, and only the
  # canonical one can match its own document), a host and a path, no
  # dot-segments, no fragment, no userinfo and no query (SHOULD NOT in the
  # draft; refused here, since relaxing later is compatible and tightening
  # isn't).
  def parse(client_id)
    if client_id.is_a?(String) && client_id.length <= MAX_LENGTH && client_id.start_with?("https://")
      uri = URI.parse(client_id)

      if uri.host.present? && uri.path.present? && uri.fragment.nil? && \
          uri.userinfo.nil? && uri.query.nil? && no_dot_segments?(uri.path)
        uri
      end
    end
  rescue URI::InvalidURIError
    nil
  end

  def host(client_id)
    parse(client_id)&.host
  end

  private
    def no_dot_segments?(path)
      path.split("/", -1).none? { |segment| segment == "." || segment == ".." }
    end
end
