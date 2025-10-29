class Current < ActiveSupport::CurrentAttributes
  attribute :session, :membership, :user
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  delegate :identity, to: :session, allow_nil: true

  def session=(value)
    super(value)

    unless value.nil?
      self.membership = identity.memberships.find_by(tenant: ApplicationRecord.current_tenant)
      self.user = membership&.user
    end
  end
end
