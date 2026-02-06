class Stripe::WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_account
  skip_forgery_protection

  def create
    if event = verify_webhook_signature
      dispatch_stripe_event(event)
      head :ok
    else
      head :bad_request
    end
  end

  private
    def dispatch_stripe_event(event)
      case event.type
      when "checkout.session.completed"
        sync_new_subscription(event.data.object.subscription, plan_key: event.data.object.metadata["plan_key"]) if event.data.object.mode == "subscription"
      when "customer.subscription.updated", "customer.subscription.deleted"
        sync_subscription(event.data.object.id)
      end
    end

    def verify_webhook_signature
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      Stripe::Webhook.construct_event(payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"])
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Stripe webhook signature verification failed: #{e.message}"
      nil
    end

    def sync_new_subscription(stripe_subscription_id, plan_key:)
      sync_subscription(stripe_subscription_id) do |subscription_properties|
        subscription_properties[:plan_key] = plan_key if plan_key
      end
    end

    # Always fetch fresh subscription data from Stripe to handle out-of-order
    # event delivery. Not relying on payload data.
    def sync_subscription(stripe_subscription_id)
      stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)

      if subscription = find_subscription_by_stripe_customer(stripe_subscription.customer)
        subscription_properties = {
          stripe_subscription_id: stripe_subscription.id,
          status: stripe_subscription.status,
          current_period_end: current_period_end_for(stripe_subscription),
          cancel_at: stripe_subscription.cancel_at ? Time.at(stripe_subscription.cancel_at) : nil,
          next_amount_due_in_cents: next_amount_due_for(stripe_subscription),
          plan_key: plan_key_for(stripe_subscription)
        }

        yield subscription_properties if block_given?
        subscription_properties[:stripe_subscription_id] = nil if stripe_subscription.status == "canceled"

        subscription.update!(subscription_properties)
      end
    end

    def find_subscription_by_stripe_customer(id)
      Account::Subscription.find_by(stripe_customer_id: id)
    end

    def current_period_end_for(stripe_subscription)
      timestamp = stripe_subscription.items.data.first&.current_period_end
      Time.at(timestamp) if timestamp
    end

    def next_amount_due_for(stripe_subscription)
      return nil if stripe_subscription.status == "canceled"

      preview = Stripe::Invoice.create_preview(customer: stripe_subscription.customer, subscription: stripe_subscription.id)
      preview.amount_due
    rescue Stripe::InvalidRequestError
      nil
    end

    def plan_key_for(stripe_subscription)
      price_id = stripe_subscription.items.data.first&.price&.id
      Plan.find_by_price_id(price_id)&.key
    end
end
