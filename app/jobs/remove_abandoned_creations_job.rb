class RemoveAbandonedCreationsJob < ApplicationJob
  queue_as :default

  def perform
    ApplicationRecord.tenants.each do |tenant|
      ApplicationRecord.while_tenanted(tenant) do
        Bubble.remove_abandoned_creations
      end
    end
  end
end
