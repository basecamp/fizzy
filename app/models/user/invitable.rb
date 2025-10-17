module User::Invitable
  extend ActiveSupport::Concern

  class_methods do
    def invite(**attributes)
      create!(attributes).tap do |user|
        IdentityProvider.link(email_address: user.email_address, to: ApplicationRecord.current_tenant)
        IdentityProvider.send_magic_link(user.email_address)
      rescue
        user.destroy!
        raise
      end
    end
  end
end
