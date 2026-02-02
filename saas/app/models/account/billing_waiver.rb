class Account::BillingWaiver < SaasRecord
  belongs_to :account

  def subscription
    @subscription ||= Account::Subscription.new(plan: Plan.paid_with_extra_storage)
  end
end
