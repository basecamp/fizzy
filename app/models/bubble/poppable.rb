module Bubble::Poppable
  extend ActiveSupport::Concern

  AUTO_POP_AFTER = 30.days

  included do
    has_one :pop, dependent: :destroy

    scope :popped, -> { joins(:pop) }
    scope :active, -> { where.missing(:pop) }

    scope :due_to_be_popped, -> { active.where(last_active_at: ..AUTO_POP_AFTER.ago) }
  end

  class_methods do
    def auto_pop_all_due
      due_to_be_popped.find_each do |bubble|
        bubble.pop!(user: bubble.bucket.account.users.system)
      end
    end
  end

  def auto_pop_at
    last_active_at + AUTO_POP_AFTER if last_active_at
  end

  def popped?
    pop.present?
  end

  def active?
    !popped?
  end

  def popped_by
    pop&.user
  end

  def popped_at
    pop&.created_at
  end

  def pop!(user: Current.user, reason: nil)
    unless popped?
      transaction do
        create_pop! user: user, reason: reason
        track_event :popped, creator: user
      end
    end
  end

  def unpop
    pop&.destroy
  end
end
