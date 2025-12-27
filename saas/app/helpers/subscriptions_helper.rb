module SubscriptionsHelper
  def storage_to_human_size(bytes)
    number_to_human_size(bytes).delete(" ")
  end

  def subscription_period_end_action(subscription)
    if subscription.to_be_canceled?
      "Your Fizzy subscription ends on"
    elsif subscription.canceled?
      "Your Fizzy subscription ended on"
    else
      "Your next payment is <b>#{ format_currency(subscription.next_amount_due) }</b> on".html_safe
    end
  end

  def format_currency(amount)
    number_to_currency(amount, precision: (amount % 1).zero? ? 0 : 2)
  end
end
