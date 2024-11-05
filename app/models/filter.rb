class Filter < ApplicationRecord
  include Bucketable
  include Assignments, Buckets, Indexes, Tags, Titled

  KNOWN_PARAMS = %i[ indexed_by bucket_ids assignments tag_ids ]

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_one :account, through: :creator

  class << self
    def default_params
      { "indexed_by" => "most_active" }
    end
  end

  def bubbles
    @bubbles ||= begin
      result = creator.accessible_bubbles
      result = result.indexed_by(indexed_by)
      result = result.active unless indexed_by.popped?
      result = result.in_bucket(buckets) if buckets.present?
      result = result.tagged_with(tags) if tags.present?
      result = result.unassigned if assignments.unassigned?
      result = result.assigned_to(assignees) if assignees.present?
      result
    end
  end

  def to_params
    ActionController::Parameters.new(params).permit(*KNOWN_PARAMS).tap do |params|
      params[:filter_id] = bucket.id if persisted?
    end
  end

  def cacheable?
    buckets.exists?
  end

  def savable?
    !bucket_default?
  end

  private
    def bucket_default?
      non_default_params.keys == %w[ bucket_ids ] && buckets.one?
    end

    def non_default_params
      params.reject { |k, v| self.class.default_params[k] == v }
    end
end
