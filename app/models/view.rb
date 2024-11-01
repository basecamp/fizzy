class View < ApplicationRecord
  include Assignment, Indexes, Summarized, Tags

  KNOWN_FILTERS = %i[ indexed_by bucket_id assignment tag_ids ]

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :bucket, optional: true

  has_one :account, through: :creator

  scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }

  class << self
    def default_indexed_by
      "most_active"
    end
  end

  def bubbles
    @bubbles ||= begin
      result = creator.visible_bubbles
      result = result.active unless indexed_by.popped?
      result = result.indexed_by(indexed_by.presence || self.class.default_indexed_by)
      result = result.in_bucket(bucket) if bucket.present?
      result = result.tagged_with(tags) if tags.present?
      result = result.unassigned if assignment.unassigned?
      result = result.assigned_to(assignees) if assignees.present?
      result
    end
  end

  def to_params
    ActionController::Parameters.new(filters.merge(bucket_id: bucket_id).compact).permit(*KNOWN_FILTERS)
  end

  def bucket_default?
    bucket && filters.empty?
  end
end
