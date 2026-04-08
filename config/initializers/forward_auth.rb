# frozen_string_literal: true

# Forward Auth (e.g. Stargate) integration: trust X-Auth-Email and related
# headers only when the request comes from a trusted source (IP or secret header).
# See docs/forward_auth.md for usage.
#
Rails.application.config.to_prepare do
  Rails.application.config.forward_auth = ForwardAuth::Config.new(
    enabled: ActiveModel::Type::Boolean.new.cast(ENV["FORWARD_AUTH_ENABLED"]),
    trusted_ips: ENV.fetch("FORWARD_AUTH_TRUSTED_IPS", "").split(",").map(&:strip).reject(&:blank?),
    secret_header: ENV["FORWARD_AUTH_SECRET_HEADER"].presence,
    secret: ENV["FORWARD_AUTH_SECRET"].presence,
    auto_provision: ActiveModel::Type::Boolean.new.cast(ENV.fetch("FORWARD_AUTH_AUTO_PROVISION", "false")),
    default_role: ENV.fetch("FORWARD_AUTH_DEFAULT_ROLE", "member").to_s.strip.downcase.presence || "member",
    create_session: ActiveModel::Type::Boolean.new.cast(ENV.fetch("FORWARD_AUTH_CREATE_SESSION", "true")),
    use_email_local_part_and_lock_email: ActiveModel::Type::Boolean.new.cast(ENV.fetch("FORWARD_AUTH_USE_EMAIL_LOCAL_PART_AND_LOCK_EMAIL", "false")),
    auto_create_account: ActiveModel::Type::Boolean.new.cast(ENV.fetch("FORWARD_AUTH_AUTO_CREATE_ACCOUNT", "true")),
    auto_create_account_name: ENV.fetch("FORWARD_AUTH_AUTO_CREATE_ACCOUNT_NAME", "My Workspace").strip.presence || "My Workspace"
  )
end
