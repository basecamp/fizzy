module TenantTestHelper
  module Unit
    extend ActiveSupport::Concern

    included do
      # For single-process tests
      @@current_tenant_dbname = "test"
      ApplicationRecord.connecting_to(shard: :test)

      # For parallel tests
      parallelize_setup do |j|
        @@current_tenant_dbname = "test-tenant-#{j}"
        ApplicationRecord.connecting_to(shard: @@current_tenant_dbname.to_sym)
      end

      setup do
        @current_tenant = Tenant.create!(slug: "test", dbname: @@current_tenant_dbname)
      end
    end
  end

  module Integration
    extend ActiveSupport::Concern

    included do
      setup do
        integration_session.host = "#{@current_tenant.slug}.example.com"
      end
    end
  end
end
