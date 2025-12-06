class Account::AdjustStorageJob < ApplicationJob
  queue_as :backend

  limits_concurrency to: 1, key: ->(account, delta) { account }

  def perform(account, delta)
    account.adjust_storage(delta)
  end
end
