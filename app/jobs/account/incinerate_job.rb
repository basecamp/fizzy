class Account::IncinerateJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :incineration

  def perform
    step :incineration do |step|
      Account.up_for_incineration.find_each(start: step.cursor) do |account|
        account.incinerate
        step.advance! from: account.id
      end
    end
  end
end
