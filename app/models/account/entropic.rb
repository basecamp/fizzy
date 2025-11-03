module Account::Entropic
  extend ActiveSupport::Concern

  DEFAULT_ENTROPY_PERIOD = 30.days

  included do
    has_one :entropy, as: :container, dependent: :destroy
    after_create -> { create_entropy!(auto_postpone_period: DEFAULT_ENTROPY_PERIOD) }
  end
end
