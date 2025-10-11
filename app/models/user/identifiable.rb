module User::Identifiable
  extend ActiveSupport::Concern

  included do
    has_one :membership, ->(user) { where(user_tenant: user.tenant) }
    has_one :identity, through: :membership

    scope :with_identity, ->(identity) { where(id: identity.memberships.where(user_tenant: ApplicationRecord.current_tenant).pluck(:user_id)) }
  end

  def set_identity(token_identity)
    if token_identity.present?
      if identity.nil?
        token_identity.memberships.create!(user_id: id, user_tenant: tenant, email_address: email_address, account_name: Account.sole.name)
      elsif identity != token_identity
        Identity.transaction do
          identity.memberships.update_all(identity_id: token_identity.id)
          identity.destroy
        end
      end
      token_identity
    elsif identity.present?
      identity
    else
      Identity.create!.tap do |identity|
        identity.memberships.create!(user_id: id, user_tenant: tenant, email_address: email_address, account_name: Account.sole.name)
      end
    end
  end
end
