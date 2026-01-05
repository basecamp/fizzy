class Account::IncinerateJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :incineration

  def perform
    step :incineration do |step|
      Account.up_for_incineration.find_each do |account|
        account.incinerate
        step.advance!
      end
    end
  end
end
