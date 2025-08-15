module AccountsHelper
  def other_accounts(user = Current.user)
    if identity = user.signal_user&.identity
      identity.accounts
        .where(product: SignalId.product.name)
        .where.not(queenbee_id: Account.sole.queenbee_id)
    else
      []
    end
  end
end
