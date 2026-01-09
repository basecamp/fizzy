# rbs_inline: enabled

module Board::Entropic
  extend ActiveSupport::Concern

  # @type self: singleton(Board) & singleton(Board::Entropic)
  # @type instance: Board & Board::Entropic

  included do
    delegate :auto_postpone_period, to: :entropy
    has_one :entropy, as: :container, dependent: :destroy
  end

  def entropy
    super || account.entropy
  end

  def auto_postpone_period=(new_value)
    entropy ||= association(:entropy).reader || self.build_entropy
    entropy.update auto_postpone_period: new_value
  end
end
