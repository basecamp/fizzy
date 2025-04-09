class Event < ApplicationRecord
  include Particulars

  belongs_to :creator, class_name: "User"
  belongs_to :summary, touch: true, class_name: "EventSummary"
  belongs_to :card

  has_one :account, through: :creator
  has_one :message, through: :summary
  has_one :comment, through: :message, source: :messageable, source_type: "Comment"

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :non_boosts, -> { where.not action: :boosted }
  scope :boosts, -> { where action: :boosted }
  scope :comments, -> { where action: :commented }

  after_create -> { card.touch_last_active_at }

  def boosted?
    action == "boosted"
  end

  def commented?
    action == "commented"
  end

  def generate_notifications
    Notifier.for(self)&.generate
  end

  def generate_notifications_later
    GenerateNotificationsJob.perform_later self
  end
end
