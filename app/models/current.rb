class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer, :identity_token

  delegate :identity, to: :session, allow_nil: true

  def user
    membership = identity&.memberships&.find_by(tenant: ApplicationRecord.current_tenant)

    if membership
      User.find_by(email_address: identity.email_address)
    end
  end
end
