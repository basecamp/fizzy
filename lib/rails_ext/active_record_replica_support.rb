# frozen_string_literal: true

# Adds a helper method to check if replica database connections are configured
# and automatically configures read/write splitting when replicas are available.
#
# Usage:
#   class ApplicationRecord < ActiveRecord::Base
#     configure_replica_connections
#   end
module ActiveRecordReplicaSupport
  extend ActiveSupport::Concern

  class_methods do
    # Automatically configures connects_to for read/write splitting if a replica
    # database is configured for the current environment. This is a no-op if no
    # replica configuration exists.
    #
    # Example:
    #   class ApplicationRecord < ActiveRecord::Base
    #     configure_replica_connections
    #   end
    def configure_replica_connections
      if replica_configured?
        connects_to database: { writing: :primary, reading: :replica }
      end
    end

    # Returns true if a replica database configuration exists for the current
    # environment. This allows different database adapters to opt in or out of
    # read/write splitting based on their database.yml configuration.
    #
    # Example:
    #   ApplicationRecord.replica_configured? # => true for MySQL, false for SQLite
    def replica_configured?
      configurations.find_db_config("replica").present?
    end

    # Execute block using read replica if available, otherwise use primary.
    #
    # Example:
    #   ApplicationRecord.with_reading_role { User.count }
    def with_reading_role(&block)
      if replica_configured?
        connected_to(role: :reading, &block)
      else
        yield
      end
    end
  end
end

ActiveRecord::Base.include ActiveRecordReplicaSupport
