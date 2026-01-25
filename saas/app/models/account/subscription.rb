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

  def pause
    if stripe_subscription_id.present?
      Stripe::Subscription.update(
        stripe_subscription_id,
        pause_collection: { behavior: "void" }
      )
    end
  end

  def resume
    if stripe_subscription_id.present?
      Stripe::Subscription.update(
        stripe_subscription_id,
        pause_collection: ""
      )
    end
  end

  def cancel
    Stripe::Subscription.cancel(stripe_subscription_id) if stripe_subscription_id.present?
  rescue Stripe::InvalidRequestError => e
    # Subscription already deleted/canceled in Stripe - treat as success
    Rails.logger.warn "Stripe subscription #{stripe_subscription_id} not found during cancel: #{e.message}"
  end

  def sync_customer_email_to_stripe
    if stripe_customer_id && (email = owner_email)
      Stripe::Customer.update(stripe_customer_id, email: email)
    end
  rescue Stripe::InvalidRequestError => e
    # Customer already deleted in Stripe - treat as success
    Rails.logger.warn "Stripe customer #{stripe_customer_id} not found during email sync: #{e.message}"
  end

  private
    # Account owner email for Stripe customer record. Returns nil when:
    # - No owner exists (ownership being transferred, account in limbo)
    # - Owner has no identity (deactivated user)
    def owner_email
      account.users.owner.first&.identity&.email_address
    end
end
