module Bubble::Assignable
  extend ActiveSupport::Concern

  included do
    has_many :assignments, dependent: :delete_all
    has_many :assignees, through: :assignments

    scope :unassigned, -> { where.missing :assignments }
    scope :assigned_to, ->(users) { joins(:assignments).where(assignments: { assignee: users }) }
  end

  def assign(users, assigner: Current.user)
    assignee_rows = Array(users).collect { |user| { assignee_id: user.id, assigner_id: assigner.id, bubble_id: id } }

    transaction do
      Assignment.insert_all assignee_rows
      track_event :assigned, assignee_ids: assignee_rows.pluck(:assignee_id)
    end
  end
end
