class Account::Incineration
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def perform
    cancel_subscription
    account.destroy
  end

  private
    def cancel_subscription
    end
end
