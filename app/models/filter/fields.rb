# rbs_inline: enabled

module Filter::Fields
  extend ActiveSupport::Concern

  # @type self: singleton(Filter) & singleton(Filter::Fields)

  INDEXES = %w[ all closed not_now stalled postponing_soon golden ]
  SORTED_BY = %w[ newest oldest latest ]

  delegate :default_value?, to: :class

  class_methods do
    def default_values
      { indexed_by: "all", sorted_by: "latest" }
    end

    def default_value?(key, value)
      default_values[key.to_sym].eql?(value)
    end

    def indexed_by_human_name(index)
      case index
      when "postponing_soon"
        "Closing soon"
      when "closed"
        "Done"
      when "all"
        "Open"
      else
        index.humanize
      end
    end
  end

  included do
    store_accessor :fields, :assignment_status, :indexed_by, :sorted_by, :terms,
      :card_ids, :creation, :closure

    def assignment_status
      super.to_s.inquiry
    end

    def indexed_by
      (super || default_indexed_by).inquiry
    end

    def sorted_by
      (super || default_sorted_by).inquiry
    end

    def creation_window
      TimeWindowParser.parse(creation)
    end

    def closure_window
      TimeWindowParser.parse(closure)
    end

    def terms
      Array(super)
    end

    def terms=(value)
      super(Array(value).filter(&:present?))
    end
  end

  def with(**fields)
    # @type self: Filter & Filter::Fields
    creator.filters.from_params(as_params).tap do |filter|
      fields.each do |key, value|
        filter.public_send("#{key}=", value)
      end
    end
  end

  def default_indexed_by
    # @type self: Filter & Filter::Fields
    self.class.default_values[:indexed_by]
  end

  #: -> bool
  def default_indexed_by?
    # @type self: Filter & Filter::Fields
    default_value?(:indexed_by, indexed_by)
  end

  def default_sorted_by
    # @type self: Filter & Filter::Fields
    self.class.default_values[:sorted_by]
  end

  #: -> bool
  def default_sorted_by?
    # @type self: Filter & Filter::Fields
    default_value?(:sorted_by, sorted_by)
  end
end
