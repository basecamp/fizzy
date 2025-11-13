class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  delegate :identity, to: :session, allow_nil: true

  def session=(value)
    super(value)

    if value.present? && account.present?
      self.user = identity.users.find_by(account: account)
    end
  end

  def account=(value)
    super(value)

    if value.present? && identity.present?
      self.user = identity.users.find_by(account: value)
    end
  end
end
