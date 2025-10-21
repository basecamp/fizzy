module User::Invitable
  extend ActiveSupport::Concern

  class_methods do
    def invite(**attributes)
      create!(attributes).tap do |user|
        IdentityProvider.send_magic_link(user.email_address)
      rescue => e
        user.destroy!
        raise e
      end
    end
  end
end
