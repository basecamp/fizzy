# To ease testing of limits
class Account::OverriddenLimits < SaasRecord
  belongs_to :account
end
