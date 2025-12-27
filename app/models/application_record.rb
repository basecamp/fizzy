class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  configure_replica_connections
end
