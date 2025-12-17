class Account::BillingWaiver < SaasRecord
  belongs_to :account

  def subscription
    @subscription ||= Account::Subscription.new(plan_key: Plan.paid.key)
  end
end
