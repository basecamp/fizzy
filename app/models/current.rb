class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  delegate :identity, to: :session, allow_nil: true

  def session=(value)
    super(value)

    if value.present? && Current.account.present?
      self.user = identity.users.find_by(account: Current.account)
    end
  end
end
