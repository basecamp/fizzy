module View::Indexes
  extend ActiveSupport::Concern

  INDEXES = %w[ most_active most_discussed most_boosted newest oldest popped ]

  included do
    store_accessor :filters, :indexed_by
  end
end
