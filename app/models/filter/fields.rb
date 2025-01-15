module Filter::Fields
  extend ActiveSupport::Concern

  INDEXES = %w[ most_discussed most_boosted newest oldest popped ]

  delegate :default_fields, to: :class

  class_methods do
    def default_fields
      { "indexed_by" => "most_active", "bubble_limit" => "10" }
    end
  end

  included do
    store_accessor :fields, :assignment_status, :indexed_by, :bubble_limit, :terms

    def assignment_status
      super.to_s.inquiry
    end

    def indexed_by
      (super || default_fields["indexed_by"]).inquiry
    end

    def bubble_limit
      super || default_fields["bubble_limit"]
    end

    def terms
      Array(super)
    end
  end

  def default_indexed_by?
    indexed_by == default_fields["indexed_by"]
  end
end
