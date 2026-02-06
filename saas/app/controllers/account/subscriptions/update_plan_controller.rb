class Account::Subscriptions::UpdatePlanController < ApplicationController
  before_action :ensure_admin

  def create
    portal_session = Stripe::BillingPortal::Session.create(
      customer: subscription.stripe_customer_id,
      return_url: account_settings_url(anchor: "subscription"),
      flow_data: {
        type: "subscription_update_confirm",
        subscription_update_confirm: {
          subscription: subscription.stripe_subscription_id,
          items: [ { id: stripe_subscription_item_id, price: target_plan.stripe_price_id } ]
        }
      }
    )

    redirect_to portal_session.url, allow_other_host: true
  end

  private
    def target_plan
      raise NotImplementedError
    end

    def subscription
      @subscription ||= Current.account.subscription
    end

    def stripe_subscription_item_id
      Stripe::Subscription.retrieve(subscription.stripe_subscription_id).items.data.first.id
    end
end
