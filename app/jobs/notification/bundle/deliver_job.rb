class Notification::Bundle::DeliverJob < ApplicationJob
  include SmtpDeliveryErrorHandling

  queue_as :backend

  def perform(bundle)
    bundle.deliver
  end
end
