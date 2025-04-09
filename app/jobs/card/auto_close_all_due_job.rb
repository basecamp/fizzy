class Card::AutoCloseAllDueJob < ApplicationJob
  queue_as :default

  def perform
    ApplicationRecord.with_each_tenant do |tenant|
      Card.auto_close_all_due
    end
  end
end
