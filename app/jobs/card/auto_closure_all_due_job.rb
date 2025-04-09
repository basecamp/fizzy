class Card::AutoPopAllDueJob < ApplicationJob
  queue_as :default

  def perform
    ApplicationRecord.with_each_tenant do |tenant|
      Card.auto_closure_all_due
    end
  end
end
