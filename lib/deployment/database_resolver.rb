module Deployment
  class DatabaseResolver < ActiveRecord::Middleware::DatabaseSelector::Resolver
    def self.in_primary_datacenter?
      ENV["PRIMARY_DATACENTER"].present?
    end

    def reading_request?(request)
      # Disables writes (and so primary-DB stickiness) in non-primary datacenters
      super || !DatabaseResolver.in_primary_datacenter?
    end

    private
      def read_from_primary?
        # Only the primary datacenter can read from the primary database, non-primary DCs have local DB replicas
        super && DatabaseResolver.in_primary_datacenter?
      end
  end
end
