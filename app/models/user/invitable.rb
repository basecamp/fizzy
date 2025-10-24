module User::Invitable
  extend ActiveSupport::Concern

  class_methods do
    def invite(**attributes)
      create!(attributes).tap do |user|
        Identity.find_or_create_by!(email_address: user.email_address).send_magic_link
      rescue => e
        user.destroy!
        raise e
      end
    end
  end
end
