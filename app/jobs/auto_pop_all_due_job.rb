class AutoPopAllDueJob < ApplicationJob
  queue_as :default

  def perform
    ApplicationRecord.tenants.each do |tenant|
      ApplicationRecord.while_tenanted(tenant) do
        Bubble.auto_pop_all_due
      end
    end
  end
end
