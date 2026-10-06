class Oauth::Client < ApplicationRecord
  has_many :access_tokens, class_name: "Identity::AccessToken"

  has_secure_token :client_id, length: 32

  validates :name, presence: true, length: { maximum: 255 }
  validates :client_id, uniqueness: true, allow_nil: true
  validates :redirect_uris, presence: true
  validate :redirect_uris_are_valid

  attribute :redirect_uris, default: -> { [] }
  attribute :scopes, default: -> { %w[ read ] }

  scope :trusted, -> { where trusted: true }
  scope :dynamically_registered, -> { where dynamically_registered: true }


  def loopback?
    redirect_uris.all? { |uri| loopback_uri?(uri) }
  end

  def allows_redirect?(uri)
    redirect_uris.include?(uri) || (loopback? && loopback_uri?(uri) && matching_loopback?(uri))
  end

  def allows_scope?(requested_scope)
    requested = requested_scope.to_s.split
    requested.present? && requested.all? { |s| scopes.include?(s) }
  end

  private
    def redirect_uris_are_valid
      redirect_uris.each { |uri| validate_redirect_uri(uri) }
    end

    def validate_redirect_uri(uri)
      parsed = URI.parse(uri)

      if parsed.fragment.present?
        errors.add :redirect_uris, "must not contain fragments"
      end

      if dynamically_registered? && !valid_loopback_uri?(parsed)
        errors.add :redirect_uris, "must be a local loopback URI for dynamically registered clients"
      end
    rescue URI::InvalidURIError
      errors.add :redirect_uris, "includes an invalid URI"
    end

    def loopback_uri?(uri)
      Oauth::LOOPBACK_HOSTS.include?(URI.parse(uri).host)
    rescue URI::InvalidURIError
      false
    end

    def valid_loopback_uri?(parsed)
      parsed.scheme == "http" && parsed.host.in?(Oauth::LOOPBACK_HOSTS)
    end

    # Only the port may vary, and only for an http loopback redirect (RFC 8252
    # §7.3): https or a native scheme on loopback stays exact. The host must match too:
    # 127.0.0.1, localhost and ::1 are not interchangeable, and localhost
    # may not even resolve to loopback (RFC 8252 §8.3).
    def matching_loopback?(uri)
      parsed = URI.parse(uri)

      redirect_uris.any? do |redirect_uri|
        redirect = URI.parse(redirect_uri)

        redirect.scheme == "http" && parsed.scheme == "http" &&
          redirect.host.in?(Oauth::LOOPBACK_HOSTS) &&
          redirect.host.casecmp?(parsed.host.to_s) &&
          redirect.path == parsed.path &&
          redirect.query == parsed.query
      end
    rescue URI::InvalidURIError
      false
    end
end
