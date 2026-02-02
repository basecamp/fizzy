module Account::Cancellable
  extend ActiveSupport::Concern

  included do
    has_one :cancellation, dependent: :destroy

    define_callbacks :cancel
    define_callbacks :reactivate
  end

  def cancel(initiated_by: Current.user)
    with_lock do
      if cancellable? && active?
        run_callbacks :cancel do
          create_cancellation!(initiated_by: initiated_by)
        end

        AccountMailer.cancellation(cancellation).deliver_later
      end
    end
  end

  def reactivate
    with_lock do
      if cancelled?
        run_callbacks :reactivate do
          cancellation.destroy
        end
      end
    end
  end

  def cancelled?
    cancellation.present?
  end

  def cancellable?
    Account.accepting_signups?
  end
end
