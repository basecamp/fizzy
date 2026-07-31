class ApplicationPushNotification < ActionPushNative::Notification
  queue_as :default

  class << self
    # Native push runs only where APNs/FCM credentials are provisioned: production
    # and beta. Staging is deliberately unprovisioned, so it enqueues no-op jobs.
    # ENABLE_NATIVE_PUSH=true is the escape hatch for development (via exe/push-dev)
    # or any environment that gets credentials later.
    def enable?
      Rails.env.production? || Rails.env.beta? || ENV["ENABLE_NATIVE_PUSH"] == "true"
    end

    def verify_credentials!
      config = ActionPushNative.config

      { "APNS_KEY_ID" => config.dig(:apple, :key_id),
        "APNS_ENCRYPTION_KEY_B64" => config.dig(:apple, :encryption_key),
        "FCM_ENCRYPTION_KEY_B64" => config.dig(:google, :encryption_key) }.each do |env_var, value|
        raise "Native push is enabled but #{env_var} is not set" if value.blank?
      end
    end
  end

  self.enabled = enable?
  verify_credentials! if enabled
end
