module Filter::Resources
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :tags
    has_and_belongs_to_many :buckets
    has_and_belongs_to_many :assignees, class_name: "User", join_table: "assignees_filters", association_foreign_key: "assignee_id"
    has_and_belongs_to_many :assigners, class_name: "User", join_table: "assigners_filters", association_foreign_key: "assigner_id"
  end

  # +resource_ids_for+ uses `resource#ids` instead of `#resource_ids`
  # because the latter won't work on unpersisted filters.
  def resource_ids_for(resource)
    resource.ids.map(&:to_s)
  end

  def resource_removed(resource)
    kind = resource.class.model_name.plural
    send "#{kind}=", send(kind).without(resource)
    empty? ? destroy! : save!
  rescue ActiveRecord::RecordNotUnique
    destroy!
  end

  def buckets
    creator.buckets.where id: super.ids
  end
end
