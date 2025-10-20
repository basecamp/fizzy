module User::Identifyable
  extend ActiveSupport::Concern

  included do
    after_commit :unlink_identity, on: :destroy
  end

  def identity
    Identity.find_by(email_address: email_address)
  end

  private
    def unlink_identity
      IdentityProvider.unlink(email_address: email_address, from: tenant)
    end
end
