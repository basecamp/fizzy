class Account::Subscriptions::UpgradesController < Account::Subscriptions::UpdatePlanController
  before_action :ensure_upgradeable

  private
    def target_plan
      Plan.paid_with_extra_storage
    end

    def ensure_upgradeable
      head :bad_request unless subscription.plan == Plan.paid
    end
end
