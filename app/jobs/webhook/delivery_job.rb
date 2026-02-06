class Webhook::DeliveryJob < ApplicationJob
  queue_as :webhooks

  discard_on ActiveJob::DeserializationError

  def perform(delivery)
    delivery.deliver
  end
end
