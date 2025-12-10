WebAuthn.configure do |config|
  config.rp_name = "Fizzy"
  # rp_id and origin are configured per-request via WebauthnRelyingParty concern
  # to support dynamic domain configuration
end
