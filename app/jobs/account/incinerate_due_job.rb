class Account::IncinerateDueJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :incineration

  def perform
    step :incineration do |step|
      Account.due_for_incineration.find_each do |account|
        account.incinerate
        step.checkpoint!
      end
    end
  end
end
