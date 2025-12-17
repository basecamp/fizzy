module SubscriptionsHelper
  def plan_storage_limit(plan)
    number_to_human_size(plan.storage_limit).delete(" ")
  end

  def subscription_period_end_action(subscription)
    if subscription.to_be_canceled?
      "Your Fizzy subscription ends on"
    elsif subscription.canceled?
      "Your Fizzy subscription ended on"
    else
      "Your next payment of <b>#{ number_to_currency(subscription.next_amount_due) }</b> will be billed on".html_safe
    end
  end
end
