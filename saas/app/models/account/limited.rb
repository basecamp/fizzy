module Account::Limited
  extend ActiveSupport::Concern

  included do
    has_one :overridden_limits, class_name: "Account::OverriddenLimits", dependent: :destroy
  end

  NEAR_CARD_LIMIT_THRESHOLD = 100
  NEAR_STORAGE_LIMIT_THRESHOLD = 500.megabytes

  def override_limits(card_count: nil, bytes_used: nil)
    (overridden_limits || build_overridden_limits).update!(card_count:, bytes_used:)
  end

  def billed_cards_count
    overridden_limits&.card_count || cards_count
  end

  def billed_bytes_used
    overridden_limits&.bytes_used || bytes_used
  end

  def nearing_plan_cards_limit?
    plan.limit_cards? && remaining_cards_count < NEAR_CARD_LIMIT_THRESHOLD
  end

  def exceeding_card_limit?
    plan.limit_cards? && billed_cards_count > plan.card_limit
  end

  def nearing_plan_storage_limit?
    remaining_storage < NEAR_STORAGE_LIMIT_THRESHOLD
  end

  def exceeding_storage_limit?
    billed_bytes_used > plan.storage_limit
  end

  def exceeding_limits?
    exceeding_card_limit? || exceeding_storage_limit?
  end

  def reset_overridden_limits
    overridden_limits&.destroy
    reload_overridden_limits
  end

  private
    def remaining_cards_count
      plan.card_limit - billed_cards_count
    end

    def remaining_storage
      plan.storage_limit - billed_bytes_used
    end
end
