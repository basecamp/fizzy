Rails.application.configure do
  # In test environment, default tenant is set in test_helper.rb
  if Rails.env.development?
    config.active_record_tenanted.default_tenant = "686465299" # Honcho
  end
end
