module Filter::Resources
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :tags
    has_and_belongs_to_many :collections
    has_and_belongs_to_many :stages, class_name: "Workflow::Stage", join_table: "filters_stages"
    has_and_belongs_to_many :assignees, class_name: "User", join_table: "assignees_filters", association_foreign_key: "assignee_id"
    has_and_belongs_to_many :creators, class_name: "User", join_table: "creators_filters", association_foreign_key: "creator_id"
  end

  def resource_removed(resource)
    kind = resource.class.model_name.plural
    send "#{kind}=", send(kind).without(resource)
    empty? ? destroy! : save!
  rescue ActiveRecord::RecordNotUnique
    destroy!
  end

  def collections
    creator.collections.where id: super.ids
  end
end
