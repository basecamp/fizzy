module Account::Cancellable
  extend ActiveSupport::Concern

  INCINERATION_GRACE_PERIOD = 30.days

  included do
    has_one :cancellation, dependent: :destroy

    scope :up_for_incineration, -> { joins(:cancellation).where(account_cancellations: { created_at: ...INCINERATION_GRACE_PERIOD.ago }) }
  end

  def cancel(initiated_by: Current.user)
    with_lock do
      if cancellable? && active?
        cancellation = create_cancellation!(initiated_by: initiated_by)
        try(:subscription)&.pause
        AccountMailer.deletion_scheduled(cancellation).deliver_later
      end
    end
  end

  def reactivate
    with_lock do
      if cancelled?
        try(:subscription)&.resume
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
end
