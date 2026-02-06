class Account::Subscriptions::DowngradesController < Account::Subscriptions::UpdatePlanController
  before_action :ensure_downgradeable

  private
    def target_plan
      Plan.paid
    end

    def ensure_downgradeable
      head :bad_request unless subscription.plan == Plan.paid_with_extra_storage
    end
end
