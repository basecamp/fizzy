module User::Invitable
  extend ActiveSupport::Concern

  class_methods do
    def invite(email_address:)
      create!(email_address: email_address).tap do |user|
        IdentityProvider.link(email_address: email_address, tenant: ApplicationRecord.current_tenant)
        IdentityProvider.send_magic_link(email_address)
      rescue
        user.destroy!
        raise
      end
    end
  end
end
