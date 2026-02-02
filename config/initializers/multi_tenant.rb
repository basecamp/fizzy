Rails.application.configure do
  config.after_initialize do
    Account.multi_tenant = ENV["MULTI_TENANT"] == "true" || config.x.multi_tenant.enabled == true
  end
end
