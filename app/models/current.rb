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

  def with_account(value)
    @old_account = self.account
    self.account = value
    yield
  ensure
    self.account = @old_account
  end

  def without_account
    @old_account = self.account
    self.account = nil
    yield
  ensure
    self.account = @old_account
  end
end
