Rails.application.config.to_prepare do
  ActionPack::Passkey::ChallengesController.class_eval do
    include Authorization
    include Authentication
    allow_unauthenticated_access
    disallow_account_scope
  end
end
