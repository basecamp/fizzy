class Card::AutoReconsiderAllStagnatedJob < ApplicationJob
  queue_as :default

  def perform
    ApplicationRecord.with_each_tenant do |tenant|
      Card.auto_reconsider_all_stagnated
    end
  end
end
