class Oauth::Client < ApplicationRecord
  has_many :access_tokens, class_name: "Identity::AccessToken"

  has_secure_token :client_id, length: 32

  validates :name, presence: true
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

    def matching_loopback?(uri)
      parsed = URI.parse(uri)

      redirect_uris.any? do |redirect_uri|
        redirect = URI.parse(redirect_uri)

        redirect.scheme == parsed.scheme &&
          redirect.host.in?(Oauth::LOOPBACK_HOSTS) &&
          parsed.host.in?(Oauth::LOOPBACK_HOSTS) &&
          redirect.path == parsed.path
      end
    rescue URI::InvalidURIError
      false
    end
end
