require "signal_id"

Rails.application.config.x.local_authentication = ENV["LOCAL_AUTHENTICATION"].present?

ENV["SIGNAL_ID_SECRET"] = Rails.application.credentials.signal_id_secret

Rails.application.config.to_prepare do
  SignalId.product = "fizzy"

  db_config = SignalId::Database.default_configuration
  if Rails.application.config.x.local_authentication
    db_config.each do |name, config|
      config["connect_timeout"] = 1
    end
  end
  SignalId::Database.load_configuration db_config
  SignalId::Database.enable_rw_splitting!

  silence_warnings do
    SignalId::Account::Peer = Account
    SignalId::User::Peer = User
  end
end

Rails.application.config.after_initialize do
  ActiveRecord.yaml_column_permitted_classes << SignalId::PersonName
end
