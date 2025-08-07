module Account::SignalAccount
  extend ActiveSupport::Concern

  included do
    belongs_to :signal_account, class_name: "SignalId::Account", primary_key: :queenbee_id, foreign_key: :queenbee_id, optional: true
  end

  class_methods do
    def create_with_admin_user(queenbee_id:)
      new(queenbee_id: queenbee_id).tap do |account|
        SignalId::Database.on_master do
          account.name = account.signal_account.name
          account.save!

          User.create!(
            name:           account.signal_account.owner.name,
            email_address:  account.signal_account.owner.email_address,
            signal_user_id: account.signal_account.owner.id,
            role:           "admin",
            password:       SecureRandom.hex(36) # TODO: remove password column?
          )
        end
      end
    end
  end
end
