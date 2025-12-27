class Account::SubscriptionsController < ApplicationController
  before_action :ensure_admin
  before_action :set_stripe_session, only: :show

  def show
  end

  def create
    session = Stripe::Checkout::Session.create \
      customer: find_or_create_stripe_customer,
      mode: "subscription",
      line_items: [ { price: plan_param.stripe_price_id, quantity: 1 } ],
      success_url: account_subscription_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: account_subscription_url,
      metadata: { account_id: Current.account.id, plan_key: plan_param.key },
      automatic_tax: { enabled: true },
      tax_id_collection: { enabled: true },
      billing_address_collection: "required",
      customer_update: { address: "auto", name: "auto" }

    redirect_to session.url, allow_other_host: true
  end

  private
    def plan_param
      @plan_param ||= Plan[params[:plan_key]] || Plan.paid
    end

    def set_stripe_session
      @stripe_session = Stripe::Checkout::Session.retrieve(params[:session_id]) if params[:session_id]
    end

    def find_or_create_stripe_customer
      find_stripe_customer || create_stripe_customer
    end

    def find_stripe_customer
      Stripe::Customer.retrieve(Current.account.subscription.stripe_customer_id) if Current.account.subscription&.stripe_customer_id
    end

    def create_stripe_customer
      Stripe::Customer.create(email: Current.user.identity.email_address, name: Current.account.name, metadata: { account_id: Current.account.id }).tap do |customer|
        Current.account.create_subscription!(stripe_customer_id: customer.id, plan_key: plan_param.key, status: "incomplete")
      end
    end
end
