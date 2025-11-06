module Card::Entropic
  extend ActiveSupport::Concern

  included do
    scope :due_to_be_postponed, -> do
      active
        .left_outer_joins(board: :entropy)
        .where("last_active_at <= DATETIME('now', '-' || COALESCE(entropies.auto_postpone_period, ?) || ' seconds')",
          Account.sole.entropy.auto_postpone_period)
    end

    scope :postponing_soon, -> do
      active
        .left_outer_joins(board: :entropy)
        .where("last_active_at >  DATETIME('now', '-' || COALESCE(entropies.auto_postpone_period, ?) || ' seconds')", Account.sole.entropy.auto_postpone_period)
        .where("last_active_at <= DATETIME('now', '-' || CAST(COALESCE(entropies.auto_postpone_period, ?) * 0.75 AS INTEGER) || ' seconds')", Account.sole.entropy.auto_postpone_period)
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
