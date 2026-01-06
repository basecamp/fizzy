class Notification::Bundle::DeliverJob < ApplicationJob
  include SmtpDeliveryErrorHandling

  queue_as :backend

  discard_on ActiveJob::DeserializationError

  def perform(bundle)
    bundle.deliver
  end
end
