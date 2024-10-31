class View < ApplicationRecord
  include Assignees, Indexes, Summarized, Tags

  KNOWN_FILTERS = %i[ indexed_by bucket_id assignment tag_ids ]

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :bucket, optional: true

  has_one :account, through: :creator

  scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }

  class << self
    def default_filters
      { "indexed_by" => default_indexed_by }
    end

    def default_indexed_by
      "most_active"
    end
  end

  def bubbles
    @bubbles ||= begin
      result = account.bubbles
      result = result.indexed_by(indexed_by || self.class.default_indexed_by)
      result = result.in_bucket(bucket) if bucket.present?
      result = result.tagged_with(tags) if tags.present?
      result = result.assigned_to(assignees) if assignees.present?
      result
    end
  end

  def to_params
    ActionController::Parameters.new(filters.merge(bucket_id: bucket_id).compact).permit(*KNOWN_FILTERS)
  end

  def default?
    filters.empty? || filters == self.class.default_filters
  end
end
