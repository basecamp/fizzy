module Oauth
  LOOPBACK_HOSTS = %w[ 127.0.0.1 localhost ::1 [::1] ]

  def self.table_name_prefix
    "oauth_"
  end
end
