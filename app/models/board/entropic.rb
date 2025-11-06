module Board::Entropic
  extend ActiveSupport::Concern

  included do
    delegate :auto_postpone_period, to: :entropy
    has_one :entropy, as: :container, dependent: :destroy
  end

  def entropy
    super || Account.sole.entropy
  end

  def auto_postpone_period=(new_value)
    entropy ||= association(:entropy).reader || self.build_entropy
    entropy.update auto_postpone_period: new_value
  end
end
