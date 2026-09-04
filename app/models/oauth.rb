module Oauth
  LOOPBACK_HOSTS = %w[ 127.0.0.1 localhost ::1 [::1] ]

  def self.loopback_host?(host)
    LOOPBACK_HOSTS.include?(URI.decode_www_form_component(host.to_s).downcase)
  rescue ArgumentError
    # A percent-encoding that decodes to invalid UTF-8 is not a usable host.
    # Surface it as an invalid URI so every caller — all of which already
    # rescue URI::InvalidURIError — rejects it instead of raising a 500.
    raise URI::InvalidURIError, "invalid percent-encoding in host"
  end

  def self.table_name_prefix
    "oauth_"
  end
end
