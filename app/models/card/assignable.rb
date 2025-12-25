# rbs_inline: enabled

module Card::Assignable
  extend ActiveSupport::Concern

  # @type self: singleton(Card::Concern)

  included do
    has_many :assignments, dependent: :delete_all
    has_many :assignees, through: :assignments

    scope :unassigned, -> { where.missing :assignments }
    scope :assigned_to, ->(users) { joins(:assignments).where(assignments: { assignee: users }).distinct }
    scope :assigned_by, ->(users) { joins(:assignments).where(assignments: { assigner: users }).distinct }
  end

  def toggle_assignment(user)
    assigned_to?(user) ? unassign(user) : assign(user)
  end

  def assigned_to?(user)
    # @type self: Card::Concern
    assignments.any? { |a| a.assignee_id == user.id }
  end

  def assigned?
    # @type self: Card::Concern
    assignments.any?
  end

  private
    def assign(user)
      # @type self: Card::Concern
      assignments.create! assignee: user, assigner: Current.user
      watch_by user

      track_event :assigned, assignee_ids: [ user.id ]
    rescue ActiveRecord::RecordNotUnique
      # Already assigned
    end

    def unassign(user)
      # @type self: Card::Concern
      destructions = assignments.destroy_by assignee: user
      track_event :unassigned, assignee_ids: [ user.id ] if destructions.any?
    end
end
