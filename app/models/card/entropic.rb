# rbs_inline: enabled

module Card::Entropic
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Entropic)
  # @type instance: Card & Card::Entropic
  included do
    scope :due_to_be_postponed, -> do
      active
        .joins(board: :account)
        .left_outer_joins(board: :entropy)
        .joins("LEFT OUTER JOIN entropies AS account_entropies ON account_entropies.account_id = accounts.id AND account_entropies.container_type = 'Account' AND account_entropies.container_id = accounts.id")
        .where("last_active_at <= #{connection.date_subtract('?', 'COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period)')}", Time.now)
    end

    scope :postponing_soon, -> do
      now = Time.now
      active
        .joins(board: :account)
        .left_outer_joins(board: :entropy)
        .joins("LEFT OUTER JOIN entropies AS account_entropies ON account_entropies.account_id = accounts.id AND account_entropies.container_type = 'Account' AND account_entropies.container_id = accounts.id")
        .where("last_active_at > #{connection.date_subtract('?', 'COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period)')}", now)
        .where("last_active_at <= #{connection.date_subtract('?', 'COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period) * 0.75')}", now)
    end

    delegate :auto_postpone_period, to: :board
  end

  # @rbs!
  #   def auto_postpone_period: () -> Integer

  class_methods do
    def auto_postpone_all_due
      # @type self: singleton(Card) & singleton(Card::Entropic)
      due_to_be_postponed.find_each do |card|
        card.auto_postpone(user: card.account.system_user)
      end
    end
  end

  #: -> Card::Entropy?
  def entropy
    Card::Entropy.for(self)
  end

  #: -> void
  def entropic?
    entropy.present?
  end
end
