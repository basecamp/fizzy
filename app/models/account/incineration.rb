class Account::Incineration
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def perform
    account.try(:subscription)&.cancel
    account.destroy
  end
end
