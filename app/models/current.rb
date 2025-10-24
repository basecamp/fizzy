class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  delegate :identity, to: :session, allow_nil: true
  delegate :user, to: :identity, allow_nil: true
end
