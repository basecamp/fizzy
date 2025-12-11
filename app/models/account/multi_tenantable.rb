module Account::MultiTenantable
  extend ActiveSupport::Concern

  included do
    cattr_accessor :multi_tenant, default: false
  end

  class_methods do
    def accepting_signups?
      multi_tenant || Account.none?
    end
  end
end
