class Bubble::AutoPopAllDueJob < ApplicationJob
  queue_as :default

  def perform
    ApplicationRecord.with_each_tenant do |tenant|
      Bubble.auto_pop_all_due
    end
  end
end
