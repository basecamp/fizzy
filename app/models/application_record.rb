# rbs_inline: enabled

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  configure_replica_connections

  # @rbs!
  #   def self.configure_replica_connections: () -> void
  #   def self.suppressing_turbo_broadcasts: () { () -> untyped } -> void
end
