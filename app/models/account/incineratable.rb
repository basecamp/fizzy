module Account::Incineratable
  extend ActiveSupport::Concern

  INCINERATION_GRACE_PERIOD = 30.days

  included do
    scope :due_for_incineration, -> { joins(:cancellation).where(account_cancellations: { created_at: ...INCINERATION_GRACE_PERIOD.ago }) }

    define_callbacks :incinerate
  end

  def incinerate
    run_callbacks :incinerate do
      account.destroy
    end
  end
end
