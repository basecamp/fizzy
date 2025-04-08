class Filter < ApplicationRecord
  include Fields, Params, Resources, Summarized

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_one :account, through: :creator

  class << self
    def from_params(params)
      find_by_params(params) || build(params)
    end

    def remember(attrs)
      create!(attrs)
    rescue ActiveRecord::RecordNotUnique
      find_by_params(attrs).tap(&:touch)
    end
  end

  def bubbles
    @bubbles ||= begin
      result = creator.accessible_bubbles.indexed_by(indexed_by)
      result = result.active unless indexed_by.popped?
      result = result.by_engagement_status(engagement_status) if engagement_status.present?
      result = result.unassigned if assignment_status.unassigned?
      result = result.assigned_to(assignees.ids) if assignees.present?
      result = result.where(creator_id: creators.ids) if creators.present?
      result = result.in_bucket(buckets.ids) if buckets.present?
      result = result.in_stage(stages.ids) if stages.present?
      result = result.tagged_with(tags.ids) if tags.present?
      result = terms.reduce(result) do |result, term|
        result.mentioning(term)
      end

      result
    end
  end

  def empty?
    self.class.normalize_params(as_params).blank?
  end

  def single_bucket
    buckets.first if buckets.one?
  end

  def single_workflow
    buckets.first.workflow if buckets.pluck(:workflow_id).uniq.one?
  end

  def cacheable?
    buckets.exists?
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key buckets.cache_key_with_version, super
  end
end
