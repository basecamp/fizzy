module Account::Billing
  extend ActiveSupport::Concern

  included do
    has_one :subscription, class_name: "Account::Subscription", dependent: :destroy
    has_one :billing_waiver, class_name: "Account::BillingWaiver", dependent: :destroy
  end

  def plan
    active_subscription&.plan || Plan.free
  end

  def subscribed?
    subscription.present?
  end

  def comped?
    billing_waiver.present?
  end

  def comp
    create_billing_waiver unless billing_waiver
  end

  def uncomp
    billing_waiver&.destroy
    reload_billing_waiver
  end

  private
    def active_subscription
      if comped?
        comped_subscription
      elsif subscription&.active?
        subscription
      end
    end

    def comped_subscription
      @comped_subscription ||= billing_waiver&.subscription
    end
end
