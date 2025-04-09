module Collection::Broadcastable
  extend ActiveSupport::Concern

  included do
    broadcasts_refreshes
    broadcasts_refreshes_to ->(collection) { [ collection.account, :collections ] }
  end
end
