class Oauth::Client < ApplicationRecord
  has_many :access_tokens, class_name: "Identity::AccessToken"

  has_secure_token :client_id, length: 32

  validates :name, presence: true
  validates :client_id, uniqueness: true, allow_nil: true
  validates :redirect_uris, presence: true
  validates :token_endpoint_auth_method, inclusion: { in: %w[ none client_secret_post ] }
  validate :redirect_uris_are_valid

  before_create :generate_client_secret, if: :confidential?

  attribute :redirect_uris, default: -> { [] }
  attribute :scopes, default: -> { %w[ read ] }

  scope :trusted, -> { where trusted: true }
  scope :dynamically_registered, -> { where dynamically_registered: true }


  def confidential?
    token_endpoint_auth_method == "client_secret_post"
  end

  def authenticate_secret(secret)
    confidential? && client_secret.present? && secret.present? &&
      ActiveSupport::SecurityUtils.secure_compare(client_secret, secret)
  end

  def allows_redirect?(uri)
    redirect_uris.include?(uri) || (loopback_uri?(uri) && matching_loopback?(uri))
  end

  def allows_scope?(requested_scope)
    requested = requested_scope.to_s.split
    requested.present? && requested.all? { |s| scopes.include?(s) }
  end

  private
    def generate_client_secret
      self.client_secret ||= self.class.generate_unique_secure_token
    end

    def redirect_uris_are_valid
      redirect_uris.each { |uri| validate_redirect_uri(uri) }
    end

    def validate_redirect_uri(uri)
      parsed = URI.parse(uri)

      unless parsed.fragment.nil?
        errors.add :redirect_uris, "must not contain fragments"
      end

      if dynamically_registered? && !valid_loopback_uri?(parsed) && !valid_https_uri?(parsed)
        errors.add :redirect_uris, "must be an https or local loopback URI for dynamically registered clients"
      end
    rescue URI::InvalidURIError
      errors.add :redirect_uris, "includes an invalid URI"
    end

    def loopback_uri?(uri)
      Oauth.loopback_host?(URI.parse(uri).host)
    rescue URI::InvalidURIError
      false
    end

    def valid_loopback_uri?(parsed)
      parsed.scheme == "http" && Oauth.loopback_host?(parsed.host)
    end

    def valid_https_uri?(parsed)
      parsed.scheme == "https" && parsed.host.present? && !Oauth.loopback_host?(parsed.host)
    end

    def matching_loopback?(uri)
      parsed = URI.parse(uri)

      redirect_uris.any? do |redirect_uri|
        redirect = URI.parse(redirect_uri)

        redirect.scheme == parsed.scheme &&
          Oauth.loopback_host?(redirect.host) &&
          Oauth.loopback_host?(parsed.host) &&
          redirect.path == parsed.path
      end
    rescue URI::InvalidURIError
      false
    end
end
