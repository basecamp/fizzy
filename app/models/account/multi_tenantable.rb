module Account::MultiTenantable
  extend ActiveSupport::Concern

  included do
    cattr_accessor :multi_tenant, default: false
  end

  class_methods do
    def accepting_signups?
      multi_tenant || Account.none?
      # Check if signups are globally disabled (using first account's setting as global config)
      first_account = Account.order(created_at: :asc).first
      return true if first_account.nil?

      !first_account.signups_disabled
    end
  end
end
