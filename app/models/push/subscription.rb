class Push::Subscription < ApplicationRecord
  PERMITTED_ENDPOINT_HOSTS = %w[
    jmt17.google.com
    fcm.googleapis.com
    updates.push.services.mozilla.com
    web.push.apple.com
    notify.windows.com
  ].freeze

  belongs_to :account, default: -> { user.account }
  belongs_to :user

  # The OAuth client whose grant registered this subscription. It delivers to
  # the app's own device or install, so it is the app's plumbing and ends with
  # the identity's last grant to that client (Identity::AccessToken). Sessions
  # and personal access tokens register none.
  belongs_to :oauth_client, class_name: "Oauth::Client", optional: true

  # Delivery is where an app's subscription could outlive the app, so this is
  # the guarantee: one delivers only while the user's identity holds an
  # unlapsed grant to its app. That covers every way the two come apart (the
  # grant ending, lapsing before the sweep, the user leaving the account or
  # moving to another identity, a claim racing the last grant's end), where
  # the cleanup on grant destroy only finds what the identity still reaches.
  scope :deliverable_to, ->(user) do
    where(oauth_client_id: nil).or \
      where(oauth_client_id: Identity::AccessToken.oauth.unlapsed.where(identity_id: user.identity_id).select(:oauth_client_id))
  end

  validates :endpoint, presence: true
  validate :validate_endpoint_url

  # Whoever registers an endpoint last owns it. An app that registers a fresh
  # OAuth client on reconnect keeps a device subscription it registered under
  # the old one, so it doesn't go when the old client's grant ends.
  def claim_for(oauth_client)
    update_column :oauth_client_id, oauth_client&.id unless oauth_client_id == oauth_client&.id
  end

  def notification(**params)
    WebPush::Notification.new(
      **params,
      badge: user.notifications.unread.count,
      endpoint: endpoint,
      endpoint_ip: resolved_endpoint_ip,
      p256dh_key: p256dh_key,
      auth_key: auth_key
    )
  end

  def resolved_endpoint_ip
    return @resolved_endpoint_ip if defined?(@resolved_endpoint_ip)
    @resolved_endpoint_ip = Surfguard.resolve_public_ips(endpoint_uri&.host).first
  rescue Surfguard::Unresolvable
    # A host that resolves to nothing has no usable public IP, same outcome as
    # one whose only addresses are blocked: no endpoint IP to pin, which fails
    # endpoint validation. Push has no lookup-failed surface to distinguish.
    @resolved_endpoint_ip = nil
  end

  private
    def endpoint_uri
      @endpoint_uri ||= URI.parse(endpoint) if endpoint.present?
    rescue URI::InvalidURIError
      nil
    end

    def validate_endpoint_url
      if endpoint_uri.nil?
        errors.add(:endpoint, "is not a valid URL")
      elsif endpoint_uri.scheme != "https"
        errors.add(:endpoint, "must use HTTPS")
      elsif !permitted_endpoint_host?
        errors.add(:endpoint, "is not a permitted push service")
      elsif resolved_endpoint_ip.nil?
        errors.add(:endpoint, "resolves to a private or invalid IP address")
      end
    end

    def permitted_endpoint_host?
      host = endpoint_uri&.host&.downcase
      PERMITTED_ENDPOINT_HOSTS.any? { |permitted| host&.end_with?(permitted) }
    end
end
