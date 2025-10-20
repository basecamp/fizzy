class Membership < UntenantedRecord
  belongs_to :identity, touch: true

  class << self
    def change_email_address(from:, to:, tenant:)
      identity = Identity.find_by(email_address: from)
      membership = find_by(tenant: tenant, identity: identity)

      if membership
        new_identity = Identity.find_or_create_by!(email_address: to)
        membership.update!(identity: new_identity)
      end
    end
  end
end
