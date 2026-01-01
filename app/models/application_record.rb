# rbs_inline: enabled

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  configure_replica_connections

  # @rbs!
  #   def self.configure_replica_connections: () -> void
  #   def self.suppressing_turbo_broadcasts: () { () -> untyped } -> void
  #   def self.broadcasts_refreshes: (**untyped) -> void
  #
  #   def broadcast_replace_later_to: (untyped, **untyped) -> void
  #   def broadcast_prepend_to: (untyped, **untyped) -> void
  #   def broadcast_remove_to: (untyped, **untyped) -> void
  #
  #   def self.due_to_be_postponed: () -> void
end
