module Account::Billing
  extend ActiveSupport::Concern

  included do
    has_one :subscription, class_name: "Account::Subscription", dependent: :destroy
  end

  NEAR_CARD_LIMIT_THRESHOLD = 100

  def plan
    active_subscription&.plan || Plan.free
  end

  def active_subscription
    subscription if subscription&.active?
  end

  def subscribed?
    subscription.present?
  end

  def nearing_plan_cards_limit?
    plan.limit_cards? && (plan.card_limit - cards_count) < NEAR_CARD_LIMIT_THRESHOLD
  end

  def exceeding_card_limit?
    plan.limit_cards? && cards_count > plan.card_limit
  end
end
