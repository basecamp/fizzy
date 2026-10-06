Rails.application.configure do
  settings = config.x.single_sign_on
  settings.issuer = ENV["SINGLE_SIGN_ON_ISSUER"].presence
  settings.client_id = ENV["SINGLE_SIGN_ON_CLIENT_ID"].presence
  settings.client_secret = ENV["SINGLE_SIGN_ON_CLIENT_SECRET"].presence
  settings.provider_name = ENV["SINGLE_SIGN_ON_PROVIDER_NAME"].presence
  settings.reauthentication_hours =
    ENV["SINGLE_SIGN_ON_REAUTHENTICATION_HOURS"].presence
  settings.admin_group = ENV["SINGLE_SIGN_ON_ADMIN_GROUP"].presence
  settings.account_admin_subgroup =
    ENV["SINGLE_SIGN_ON_ACCOUNT_ADMIN_SUBGROUP"].presence

  config.after_initialize do
    SingleSignOn.ensure_valid_configuration
  end
end
