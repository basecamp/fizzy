class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer
  attribute :account

  def session=(session)
    super
    Current.user = session&.user
  end

  def signal_user=(signal_user)
    self.user = signal_user&.peer
  end
end
