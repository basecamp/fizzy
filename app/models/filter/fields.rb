module Filter::Fields
  extend ActiveSupport::Concern

  INDEXES = %w[ most_discussed most_boosted newest oldest stalled ]

  delegate :default_value?, to: :class

  class_methods do
    def default_values
      { indexed_by: "most_active" }
    end

    def default_value?(key, value)
      default_values[key.to_sym].eql?(value)
    end
  end

  included do
    store_accessor :fields, :assignment_status, :indexed_by, :terms, :engagement_status

    def assignment_status
      super.to_s.inquiry
    end

    def indexed_by
      (super || default_indexed_by).inquiry
    end

    def engagement_status
      super&.inquiry
    end

    def terms
      Array(super)
    end
  end

  def with(**fields)
    creator.filters.from_params(as_params).tap do |filter|
      fields.each do |key, value|
        filter.public_send("#{key}=", value)
      end
    end
  end

  def default_indexed_by
    self.class.default_values[:indexed_by]
  end

  def default_indexed_by?
    default_value?(:indexed_by, indexed_by)
  end
end
