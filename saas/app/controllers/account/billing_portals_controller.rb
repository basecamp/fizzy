class Account::BillingPortalsController < ApplicationController
  before_action :ensure_admin
  before_action :ensure_subscribed_account

  def show
    redirect_to create_stripe_billing_portal_session.url, allow_other_host: true
  end

  private
    def ensure_subscribed_account
      unless Current.account.subscribed?
        redirect_to account_subscription_path, alert: "No billing information found"
      end
    end

    def create_stripe_billing_portal_session
      Stripe::BillingPortal::Session.create(customer: Current.account.subscription.stripe_customer_id, return_url: account_settings_url)
    end
end
