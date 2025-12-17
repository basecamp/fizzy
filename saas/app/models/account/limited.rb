module Account::Limited
  extend ActiveSupport::Concern

  included do
    has_one :overridden_limits, class_name: "Account::OverriddenLimits", dependent: :destroy
  end

  NEAR_CARD_LIMIT_THRESHOLD = 100

  def override_limits(card_count:)
    (overridden_limits || build_overridden_limits).update!(card_count:)
  end

  def billed_cards_count
    overridden_limits&.card_count || cards_count
  end

  def nearing_plan_cards_limit?
    plan.limit_cards? && remaining_cards_count < NEAR_CARD_LIMIT_THRESHOLD
  end

  def exceeding_card_limit?
    plan.limit_cards? && billed_cards_count > plan.card_limit
  end

  def reset_overridden_limits
    overridden_limits&.destroy
    reload_overridden_limits
  end

  private
    def remaining_cards_count
      plan.card_limit - billed_cards_count
    end
end
