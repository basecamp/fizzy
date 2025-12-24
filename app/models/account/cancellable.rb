module Account::Cancellable
  extend ActiveSupport::Concern

  INCINERATION_GRACE_PERIOD = 30.days

  included do
    has_one :cancellation, dependent: :destroy

    scope :up_for_incineration, -> { joins(:cancellation).where(cancellations: { created_at: ...INCINERATION_GRACE_PERIOD.ago }) }
  end

  def cancel(**attributes)
    with_lock do
      if cancellable? && active?
        create_cancellation!(**attributes)
        pause_subscription
      end
    end
  end

  def reactivate
    with_lock do
      if cancelled?
        resume_subscription
        cancellation.destroy
      end
    end
  end

  def cancelled?
    cancellation.present?
  end

  private
    def active?
      !cancelled?
    end

    def cancellable?
      Account.accepting_signups?
    end

    def pause_subscription
    end

    def resume_subscription
    end
end
