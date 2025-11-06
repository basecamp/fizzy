module Filter::Resources
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :tags
    has_and_belongs_to_many :boards
    has_and_belongs_to_many :assignees, class_name: "User", join_table: "assignees_filters", association_foreign_key: "assignee_id"
    has_and_belongs_to_many :creators, class_name: "User", join_table: "creators_filters", association_foreign_key: "creator_id"
    has_and_belongs_to_many :closers, class_name: "User", join_table: "closers_filters", association_foreign_key: "closer_id"
  end

  def resource_removed(resource)
    kind = resource.class.model_name.plural
    send "#{kind}=", send(kind).without(resource)
    empty? ? destroy! : save!
  rescue ActiveRecord::RecordNotUnique
    destroy!
  end

  def boards
    creator.boards.where id: super.ids
  end

  def board_titles
    if boards.none?
      Board.one? ? [ Board.first.name ] : [ "all boards" ]
    else
      boards.map(&:name)
    end
  end

  def boards_label
    board_titles.to_sentence
  end
end
