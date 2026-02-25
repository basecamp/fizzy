class Account::SyncStripeCustomerEmailJob < ApplicationJob
  queue_as :default
  retry_on Stripe::StripeError, wait: :polynomially_longer

  def perform(subscription)
    subscription.sync_customer_email_to_stripe
  end
end
