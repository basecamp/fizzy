class Bubble::AutoReconsiderAllStagnatedJob < ApplicationJob
  queue_as :default

  def perform
    ApplicationRecord.with_each_tenant do |tenant|
      Bubble.auto_reconsider_all_stagnated
    end
  end
end
