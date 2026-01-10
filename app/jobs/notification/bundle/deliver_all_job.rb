class Notification::Bundle::DeliverAllJob < ApplicationJob
  queue_as :backend

  discard_on ActiveJob::DeserializationError

  def perform
    Notification::Bundle.deliver_all
  end
end
