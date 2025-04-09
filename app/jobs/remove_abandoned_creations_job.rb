class RemoveAbandonedCreationsJob < ApplicationJob
  queue_as :default

  def perform
    ApplicationRecord.with_each_tenant do |tenant|
      Card.remove_abandoned_creations
    end
  end
end
