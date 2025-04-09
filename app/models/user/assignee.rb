module User::Assignee
  extend ActiveSupport::Concern

  included do
    has_many :assignments, foreign_key: :assignee_id, dependent: :destroy
    has_many :assignings, foreign_key: :assigner_id, class_name: "Assignment"
    has_many :assigned_cards, through: :assignments, source: :card
  end
end
