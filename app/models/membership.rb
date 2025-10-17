class Membership < UntenantedRecord
  belongs_to :identity, touch: true

  def user
    User.with_tenant(tenant) { User.find_by(email_address: identity.email_address) }
  end

  def account
    Account.with_tenant(tenant) { Account.sole }
  end
end
