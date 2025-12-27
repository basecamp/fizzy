class Account::Subscription < SaasRecord
  belongs_to :account

  enum :status, %w[ active past_due unpaid canceled incomplete incomplete_expired trialing paused ].index_by(&:itself)

  validates :plan_key, presence: true, inclusion: { in: Plan::PLANS.keys.map(&:to_s) }

  delegate :paid?, to: :plan

  def plan
    @plan ||= Plan.find(plan_key)
  end

  def plan=(plan)
    self.plan_key = plan.key
  end

  def to_be_canceled?
    active? && cancel_at.present?
  end

  def next_amount_due
    next_amount_due_in_cents ? next_amount_due_in_cents / 100.0 : plan.price
  end
end
