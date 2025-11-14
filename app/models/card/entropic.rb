module Card::Entropic
  extend ActiveSupport::Concern

  included do
    scope :due_to_be_postponed, -> do
      active
        .joins(board: :account)
        .left_outer_joins(board: :entropy)
        .joins("LEFT OUTER JOIN entropies AS account_entropies ON account_entropies.account_id = accounts.id AND account_entropies.container_type = 'Account' AND account_entropies.container_id = accounts.id")
        .where("last_active_at <= DATE_SUB(NOW(), INTERVAL COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period) SECOND)")
    end

    scope :postponing_soon, -> do
      active
        .joins(board: :account)
        .left_outer_joins(board: :entropy)
        .joins("LEFT OUTER JOIN entropies AS account_entropies ON account_entropies.account_id = accounts.id AND account_entropies.container_type = 'Account' AND account_entropies.container_id = accounts.id")
        .where("last_active_at >  DATE_SUB(NOW(), INTERVAL COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period) SECOND)")
        .where("last_active_at <= DATE_SUB(NOW(), INTERVAL CAST(COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period) * 0.75 AS SIGNED) SECOND)")
    end

    delegate :auto_postpone_period, to: :board
  end

  class_methods do
    def auto_postpone_all_due
      due_to_be_postponed.find_each do |card|
        card.auto_postpone(user: User.system)
      end
    end
  end

  def entropy
    Card::Entropy.for(self)
  end

  def entropic?
    entropy.present?
  end
end
