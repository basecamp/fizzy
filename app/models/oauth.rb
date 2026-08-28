module Oauth
  LOOPBACK_HOSTS = %w[ 127.0.0.1 localhost ::1 [::1] ]

  # Write permits every request, reads included, so a grant that includes
  # write is reported as "read write" wherever it is shown or echoed.
  def self.canonical_scope(scope)
    scope.to_s.split.include?("write") ? "read write" : "read"
  end

  def self.loopback_host?(host)
    LOOPBACK_HOSTS.include?(host.to_s.downcase)
  end

  def self.table_name_prefix
    "oauth_"
  end
end
