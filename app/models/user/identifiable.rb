module User::Identifiable
  extend ActiveSupport::Concern

  included do
    after_create_commit :link_identity, unless: :system?
    after_update_commit :update_email_address_on_identity, if: -> { saved_change_to_email_address? && !system? }
    after_destroy_commit :unlink_identity, unless: :system?
  end

  def identity
    Identity.find_by(email_address: email_address)
  end

  private
    def link_identity
      IdentityProvider.link(email_address: email_address, to: tenant)
    end

    def unlink_identity
      IdentityProvider.unlink(email_address: email_address, from: tenant)
    end

    def update_email_address_on_identity
      old_email, new_email = saved_change_to_email_address
      IdentityProvider.change_email_address(from: old_email, to: new_email, tenant: tenant)
    end
end
