Rails.application.configure do
  # In test environment, default tenant is set in test_helper.rb
  if Rails.env.development?
    # TODO: Set back to 686465299 (Honcho) for `primary` once AR::Tenanted supports per-database defaults
    config.active_record_tenanted.default_tenant = nil
  end
end
