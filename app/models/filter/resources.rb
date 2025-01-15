module Filter::Resources
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :tags
    has_and_belongs_to_many :buckets
    has_and_belongs_to_many :assignees, class_name: "User", join_table: "assignees_filters", association_foreign_key: "assignee_id"
    has_and_belongs_to_many :assigners, class_name: "User", join_table: "assigners_filters", association_foreign_key: "assigner_id"
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
