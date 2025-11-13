module Identity::Joinable
  extend ActiveSupport::Concern

  def join(account, **attributes)
    attributes[:name] ||= email_address

    transaction do
      account.users.create!(**attributes, identity: self)
    end
  end

  def member_of?(account)
    account.users.exists?(identity: self)
  end
end
